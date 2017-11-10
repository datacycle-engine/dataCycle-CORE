module DataCycleCore
  class DataHashService
    #todo refactor: class => module
    extend NormalizeService
    require 'hashdiff'

    def self.flatten_datahash_value(datahash, template_hash, debug=false)

      datahash = self.flatten_recursive(datahash.to_h, template_hash)

      if debug == true
        raise datahash.inspect
      end

      return datahash

    end

    def self.data_hash_is_dirty?(data_hash, orig_data_hash)
      return !HashDiff.diff(normalize_data_hash(data_hash), normalize_data_hash(orig_data_hash), :array_path => true).blank?
    end

    def self.get_internal_data(storage_location, value)

      internal_objects = []
      if !value.blank? && value.count > 0
        value.each do |object|
          internal_object = ("DataCycleCore::"+storage_location.classify).constantize.
              find_by(id: object['id'])
          internal_objects.push(internal_object) unless internal_object.blank?
        end
      else
        return nil
      end

      return internal_objects

    end

    def self.get_internal_template(storage_location, name, description)
      internal_template = ("DataCycleCore::"+storage_location.classify).constantize.
      find_by("template = true AND metadata->'validation'->>'name' = ? AND metadata->'validation'->>'description' = ?", name,  description )

      if internal_template.blank?
        return nil
      end

      return internal_template

    end

    def self.get_object_params(storage_location, template_name, template_description)
      template = self.get_internal_template(storage_location, template_name, template_description)
      datahash = self.get_params_from_hash(template.metadata['validation'])
      return datahash
    end

    def self.create_internal_object(storage_location, template_name, template_description, object_params, current_user)
      object = ("DataCycleCore::"+storage_location.classify).constantize.new(object_params)

      template = self.get_internal_template(storage_location, template_name, template_description)
      validation = template.metadata['validation']

      object.metadata = { 'validation' => validation }
      object.save

      if !object_params[:datahash].nil?
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],object.metadata['validation'])
        datahash['creator'] = current_user[:id]
        datahash['headline_external'] = datahash['headline']
      else
        return nil
      end

      datahash['permitted_creator'] = current_user.try(:role).try(:rank) == 3 ? [DataCycleCore::Classification.find_by(name: 'Markt Office').try(:id)] : [DataCycleCore::Classification.find_by(name: 'Team CM').try(:id)]

      object.set_data_hash(data_hash: datahash, current_user: current_user, prevent_history: true)

      #validate ?
      if object.save
        return object
      else
        return nil
      end
    end

    def self.import_data(data_set:, external_key: nil, external_source_id: nil)
      # todo: refactor import logic to work with everything
      # normalize data_set
      if data_set.is_a?(ActionController::Parameters)
        data_set = data_set.to_unsafe_h.to_h
      end
      external_key ||= data_set.values.first['url'].split('/').last
      external_source_id ||= DataCycleCore::ExternalSource.find_by(name: 'JSON-LD OEW-Medienarchiv').id
      classifications_tree_label_id = DataCycleCore::DataHashService.init_or_create_classifications_trees_label('Tags', external_source_id)

      data_template = DataCycleCore::CreativeWork.find_by(template: true, description: data_set.values.first['@type'].split(':').last)
      validation = data_template.metadata['validation']

      template_params = DataCycleCore::DataHashService.get_object_params('creative_works', data_template.headline, data_template.description)

      ActiveRecord::Base.transaction do
        content = DataCycleCore::CreativeWork.where("external_key = ? AND external_source_id = ?", external_key, external_source_id).first_or_initialize

        if content.metadata.nil?
          content.metadata = { 'validation' => validation }
        else
          content.metadata['validation'] = validation
        end

        content.external_key = external_key
        content.external_source_id = external_source_id

        data_set.each do |lang, data_hash|
          content = DataCycleCore::DataHashService.create_imported_content_with_lang(data_hash, lang, content, template_params, external_source_id)
        end

        unless content.id.nil?
          #create relation for keywords
          keywords = data_set.each.first[1]['keywords']
          unless keywords.nil?
            keywords.each do |keyword|
              classification_id = DataCycleCore::DataHashService.check_for_classification_keyword(keyword, external_source_id, classifications_tree_label_id)
              ClassificationContent
                .find_or_initialize_by(
                  content_data_id: content.id,
                  content_data_type: content.class.to_s,
                  classification_id: classification_id,
                  external_source_id: external_source_id,
                  tag: true
                ) do |relation|
                  relation.seen_at = Time.zone.now
              end.save
            end
          end
        end

        return content
      end
    end

    def self.create_imported_content_with_lang(data_hash, lang, content, template_params, external_source_id)
      data = data_hash.except('@context', '@type', 'visibility', 'keywords', 'contentLocation').deep_transform_keys{ |k| k.to_s.underscore }
      I18n.with_locale(lang) do
        unless data_hash["contentLocation"].blank?
          content_location_hash = DataCycleCore::DataHashService.get_content_location(content.id, data_hash["contentLocation"], lang, external_source_id)
          data['content_location'] = [ content_location_hash ]
        end
        data['data_type'] = nil # touch data_type to get default_value
        object_params = ActionController::Parameters.new(creative_work: ActionController::Parameters.new(datahash: data))
        object_params = object_params.require(:creative_work).permit(:datahash => template_params)

        params_hash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], content.metadata['validation'])

        errors = content.set_data_hash(data_hash: params_hash)
        # check if data is set and validations are correct
        if errors[:error].size > 0
          puts "received wrong data for id:#{content.external_key}, language: #{lang}, data: #{data} (skipping)"
          errors[:error].each do |error|
            puts error
          end

          next
        end
        content.seen_at = Time.zone.now
        content.save
      end
      return content
    end

    def self.get_content_location(creative_work_id, data_hash, lang, external_source_id)
      place_hash = {}
      place = DataCycleCore::Place.joins(:creative_work_places)
        .find_by("creative_work_places.creative_work_id" => creative_work_id)
        place_hash['id'] = place.id unless place.blank?
      if !data_hash['name'].blank? && data_hash['name'].has_key?(lang) && !data_hash['name'][lang].blank?
        place_hash['name'] = data_hash['name'][lang]
      end
      place_hash['address'] = { 'street_address' => data_hash['address'] }
      place_hash['longitude'] = data_hash.dig('geo', 'longitude').to_f
      place_hash['latitude'] = data_hash.dig('geo', 'latitude').to_f
      unless place_hash['longitude'].blank? || place_hash['latitude'].blank?
        place_hash['location'] = RGeo::Geographic.spherical_factory(srid: 4326).point(place_hash['longitude'].to_f, place_hash['latitude'].to_f)
      end
      place_hash['external_source_id'] = external_source_id
      return place_hash
    end

    def self.init_or_create_classifications_trees_label(label_string, external_source_id)
      classifications_trees_label = DataCycleCore::ClassificationTreeLabel.find_or_initialize_by(name: label_string, external_source_id: external_source_id)
      classifications_trees_label.seen_at = Time.zone.now
      classifications_trees_label.save
      classifications_trees_label.id
    end

    def self.check_for_classification_keyword(keyword, external_source_id, classifications_tree_label_id)
      classification = DataCycleCore::Classification.find_or_initialize_by(name: keyword, external_source_id: external_source_id, external_type: 'keyword') do |data_set|
        data_set.seen_at = Time.zone.now
      end
      classification.save

      # check if entries up to classification_tree with label 'Tags' exist
      class_group = DataCycleCore::ClassificationGroup.
        joins(classification_alias: [classification_tree: [:classification_tree_label]]).
        where('classification_groups.classification_id = ?', classification.id).
        where('classification_trees.external_source_id = ?', external_source_id).
        where('classification_tree_labels.name = ?', 'Tags')

      if class_group.count < 1
        classification_alias = DataCycleCore::ClassificationAlias.find_or_initialize_by(name: keyword, external_source_id: external_source_id) do |data_set|
          data_set.seen_at = Time.zone.now
        end
        classification_alias.save
        DataCycleCore::ClassificationGroup.
          find_or_initialize_by(
            classification_id: classification.id,
            classification_alias_id: classification_alias.id,
            external_source_id: external_source_id
          ) do |data_set|
            data_set.seen_at = Time.zone.now
        end.save
        DataCycleCore::ClassificationTree.
          find_or_initialize_by(
            classification_alias_id: classification_alias.id,
            external_source_id: external_source_id,
            classification_tree_label_id: classifications_tree_label_id,
            parent_classification_alias_id: nil
          ) do |data_set|
            data_set.seen_at = Time.zone.now
        end.save
      end
      return classification.id
    end


    private

      def self.get_params_from_hash(template_hash)
        temp_params = []

        template_hash['properties'].each do |key,value|
          orig_key = key
          key = "value" if value['releasable']

          if value['type'] == 'object' && !value.dig('editor', 'type').nil?
            object_properties = self.get_internal_template(value['storage_location'], value['name'], value['description'])
            key = {key.to_sym => self.get_params_from_hash(object_properties.metadata['validation'])}
          elsif value['type'] == 'object' && !value['properties'].nil? && !value['properties'].empty?
            key = {key.to_sym => self.get_params_from_hash(value)}
          elsif value['type'] == 'classificationTreeLabel' || value['type'] == 'embeddedLinkArray'
            key = {key.to_sym => []}
          else
            key = key.to_sym
          end

          key = {orig_key.to_sym => [key, "release_id", "release_comment"]} if value['releasable']

          temp_params.push(key)
        end

        return temp_params
      end

      def self.flatten_recursive(datahash, template_hash)

        temp_datahash = {}

        datahash.each do |key,value|

          properties = template_hash['properties'][key]

          if value.is_a?(::Hash)

            if properties['type'] == 'object' && !properties.dig('editor', 'type').nil? && properties.dig('editor', 'type') == 'embeddedObject'
              object_properties = self.get_internal_template(properties['storage_location'],properties['name'],properties['description'])
              temp_value = []

              value.values.each do |object_value|
                temp_value.push(self.flatten_recursive(object_value, object_properties.metadata['validation']))
              end

              value = temp_value

            elsif value['value'].is_a?(::Array)
              value['value'] = value['value'].reject { |v| v.empty? }
            end
          elsif value.is_a?(::Array)
            value = value.reject { |v| v.empty? }
          else
            #todo: add more casts ?
            if properties['type'] == 'number' && !properties['validations'].nil? && !properties['validations']['format'].nil? && properties['validations']['format'] == 'float'
              value = value.to_f
            elsif properties['type'] == 'number'
              value = value.to_i
            end

          end

          temp_datahash[key] = value
        end

        return temp_datahash
      end

  end

end
