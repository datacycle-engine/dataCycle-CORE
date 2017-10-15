module DataCycleCore
  module Jsonld

    Import = Struct.new(:max_count) do
      def self.with_configuration(**configuration_options)
        initializer_options = [
          configuration_options[:external_source_id],
          false,
          configuration_options[:page_size] || 300,
          configuration_options[:verbose] || false
        ]

        import = Import.new(*initializer_options)

        configuration_options.reject { |k, v| [:external_source_id, :page_size, :verbose].include?(k) }.each do |k,v|
          import.send("#{k}=", v) unless v.nil?
        end

        import
      end

      def initialize ( uuid , incremental_update = false, page_size = 300, verbose = false )
        @external_source_id = uuid
        @download_page_size = page_size
        @verbose = verbose
        @incremental_update = incremental_update
        @log = DataCycleCore::Logger.new('jsonld_import')
        init_db
      end

      def init_db
        save_logger_level = Rails.logger.level
        Rails.logger.level = 4 unless @verbose

        @classifications_tree_label_id = init_or_create_classifications_trees_label('Tags')

        @image_classification = DataCycleCore::Classification.where(name: 'Bild').
          joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]]).
          where('classification_aliases.name = ?', 'Bild').
          where('classification_trees.parent_classification_alias_id IS NULL').
          where('classification_tree_labels.name = ?', 'Inhaltstypen').
          first.id

        Rails.logger.level = save_logger_level
      end

      def init_or_create_classifications_trees_label(label_string)
        classifications_trees_label = ClassificationTreeLabel.find_or_initialize_by(name: label_string, external_source_id: @external_source_id)
        classifications_trees_label.seen_at = Time.zone.now
        classifications_trees_label.save
        classifications_trees_label.id
      end

      def check_for_classification_keyword(keyword)
        classification = Classification.find_or_initialize_by(name: keyword, external_source_id: @external_source_id, external_type: 'keyword') do |data_set|
          data_set.seen_at = Time.zone.now
        end
        classification.save

        # check if entries up to classification_tree with label 'Tags' exist
        class_group = ClassificationGroup.
          joins(classification_alias: [classification_tree: [:classification_tree_label]]).
          where('classification_groups.classification_id = ?', classification.id).
          where('classification_trees.external_source_id = ?', @external_source_id).
          where('classification_tree_labels.name = ?', 'Tags')

        if class_group.count < 1
          classification_alias = ClassificationAlias.find_or_initialize_by(name: keyword, external_source_id: @external_source_id) do |data_set|
            data_set.seen_at = Time.zone.now
          end
          classification_alias.save
          ClassificationGroup.
            find_or_initialize_by(
              classification_id: classification.id,
              classification_alias_id: classification_alias.id,
              external_source_id: @external_source_id
            ) do |data_set|
              data_set.seen_at = Time.zone.now
          end.save
          ClassificationTree.
            find_or_initialize_by(
              classification_alias_id: classification_alias.id,
              external_source_id: @external_source_id,
              classification_tree_label_id: @classifications_tree_label_id,
              parent_classification_alias_id: nil
            ) do |data_set|
              data_set.seen_at = Time.zone.now
          end.save
        end
        return classification.id
      end

    # main import functionality
      def import(options = {})
        Mongoid.override_database(nil) #reset to default
        Mongoid.override_database("#{DownloadCreativeWork.database_name}_#{@external_source_id}")

        import_logging do
          import_creative_work
        end

        Mongoid.override_database(nil) #reset to default
      end

    private

      def import_creative_work
        data_template = CreativeWork.
          find_by(template: true, headline: DataCycleCore.default_image_type)
        validation = data_template.metadata['validation']

        template_place = Place.
          find_by(template: true, headline: DataCycleCore.default_place_type)
        contentLocation_template = template_place.metadata['validation']

        i = 0
        page_size = 50 #avoid timeout from Mongo-cursor!!!
        total_items=DownloadCreativeWork.count
        pages = total_items.fdiv(page_size).ceil
        pages.times do |index|
          DownloadCreativeWork.all.extras(:limit => page_size, :skip => (index*page_size)).each do |data_set|
            ActiveRecord::Base.transaction do
              contentLocation = nil
              to_update_image = CreativeWork
                .where(
                  "external_key = ? AND external_source_id = ?",
                  data_set.id,
                  @external_source_id
                ).first_or_initialize
              if to_update_image.metadata.nil?
                to_update_image.metadata = { 'validation' => validation }
              else
                to_update_image.metadata['validation'] = validation
              end
              to_update_image.external_key = data_set.id
              to_update_image.external_source_id = @external_source_id

              data_set.dump.each do |lang, data_hash|
                puts "#{i.to_s.ljust(5)} | #{data_set.id.ljust(51)}| #{Time.zone.now}" if (i % 250) == 0
                i += 1
## TODO: visibility when its properly defined
                data = underscore_keys(data_hash.except('@context', '@type', 'visibility', 'keywords', 'contentLocation'))
                I18n.with_locale(lang) do
                  unless data_hash["contentLocation"].blank?
                    contentLocation_hash = get_contentLocation(to_update_image.id, data_hash["contentLocation"], lang)
                    data['content_location'] = [ contentLocation_hash ]
                  end
                  data['data_type'] = nil # touch data_type to get default_value
                  errors = to_update_image.set_data_hash(data)
                  # check if data is set and validations are correct
                  if errors[:error].size > 0
                    @log.error "received wrong data for id:#{data_set.id}, language: #{lang}, data: #{data} (skipping)"
                    errors[:error].each do |error|
                      @log.error error
                    end

                    next
                  end
                  to_update_image.seen_at = Time.zone.now
                  to_update_image.save
                end
              end

              unless to_update_image.id.nil?
                #create relation for keywords
                #puts "id: #{to_update_image.id} | keywords = #{data_set.dump.each.first[1]['keywords']}"
                keywords = data_set.dump.each.first[1]['keywords']
                unless keywords.nil?
                  keywords.each do |keyword|
                    classification_id = check_for_classification_keyword(keyword)
                    ClassificationContent
                      .find_or_initialize_by(
                        content_data_id: to_update_image.id,
                        content_data_type: to_update_image.class.to_s,
                        classification_id: classification_id,
                        external_source_id: @external_source_id,
                        tag: true
                      ) do |relation|
                        relation.seen_at = Time.zone.now
                    end.save
                  end
                end
              end

              return if max_count && i >= max_count
            end
          end
        end
      end

      def get_contentLocation(creative_work_id, data_hash, lang)
        set_data = {}
        # check if place exists
        place = Place.
          joins(:creative_work_places).
          find_by("creative_work_places.creative_work_id" => creative_work_id)
        set_data['id'] = place.id unless place.blank?
        if !data_hash['name'].blank? && data_hash['name'].has_key?(lang) && !data_hash['name'][lang].blank?
          set_data['name'] = data_hash['name'][lang]
        end
        set_data['address'] = { 'street_address' => data_hash['address'] }
        set_data['longitude'] = data_hash['geo']['longitude'] unless data_hash['geo'].blank?
        set_data['latitude'] = data_hash['geo']['latitude'] unless data_hash['geo'].blank?
        unless set_data['longitude'].blank? || set_data['latitude'].blank?
          set_data['location'] = RGeo::Geographic.spherical_factory(srid: 4326).point(set_data['longitude'].to_f, set_data['latitude'].to_f)
        end
        set_data['external_source_id'] = @external_source_id
        set_data
      end

      def underscore_keys(data_hash)
        Hash[data_hash.to_a.map { |k, v| [k.to_s.underscore, v.kind_of?(Hash) ? underscore_keys(v) : v] }]
      end

    # logging ceremony for import logic
      def import_logging
        start_time = Time.zone.now
        @log.info 'BEGIN IMPORT : ' + start_time.to_s
        @log.info 'JSON-LD Importer:'
        @log.info "MongoDB: #{DownloadCreativeWork.database_name}"

        save_logger_level = Rails.logger.level
        Rails.logger.level = 4 unless @verbose

        yield

        end_time = Time.zone.now
        @log.info "  total import time: #{(end_time-start_time).round(2)} [s]"
        @log.info 'end'
        @log.info 'END IMPORT : ' + end_time.to_s

        Rails.logger.level = save_logger_level
      end
    end
  end
end
