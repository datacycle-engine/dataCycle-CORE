module DataCycleCore
  class DataHash < Content
    self.abstract_class = true

    # get data as specified in the data template
    # data hash with keys named as in schema.org
    def get_data_hash(timestamp = Time.zone.now)
      if translated_locales.include?(I18n.locale) || changes.count.positive? # for new data-sets with pending data in it
        data_hash = as_of(timestamp).try(:to_h, timestamp)
        data_hash = merge_release(data_hash, release) if is_a?(DataCycleCore::Releasable)
        data_hash
      end
    end

    # set data as specified in the data template
    # data hash with keys named as in schema.org
    def set_data_hash(data_hash:, current_user: nil, save_time: Time.zone.now, prevent_history: false)
      stripped_data_hash = data_hash
      stripped_data_hash, global_release_hash = extract_release(data_hash, true) if is_a?(DataCycleCore::Releasable) # strip also release data from embeddedObjects

      if validate?(stripped_data_hash)
        ActiveRecord::Base.transaction do
          to_history(save_time: save_time) if id.nil? == false && prevent_history == false
          data_hash, release_hash = extract_release(data_hash, false) if is_a?(DataCycleCore::Releasable) # strip release data only from this object
          set_template_data_hash(data_hash, property_definitions, save_time, current_user)
          if is_a?(DataCycleCore::Releasable)
            self.release = release_hash
            self.release_id = set_global_release(global_release_hash)
          end
          self.updated_at = save_time
          updated_by = { 'last_updated_by' => current_user.try(:id) }
          metadata.nil? ? self.metadata = updated_by : metadata.merge!(updated_by)
          if id.nil?
            self.created_at = save_time
            self.updated_at = save_time
            save
          end
          set_search
        end
      end
      validate(stripped_data_hash) # return error/warnings from validation
    end

    def destroy_content
      to_history(save_time: Time.zone.now, delete: true) unless is_history?
      delete_childs(true)
    end

    def set_data_hash_attribute(key, value, current_user, save_time = Time.zone.now)
      key_hash = schema.dig('properties', key)
      unless key_hash.nil?
        ActiveRecord::Base.transaction do
          storage_cases_set(key, value, key_hash, save_time, current_user)
        end
      end
    end

    def to_history(save_time:, parent_id: nil, delete: false)
      origin_table = self.class.to_s.split('::')[1].tableize
      data_set_history = (self.class.to_s + '::History').safe_constantize.new

      ActiveRecord::Base.transaction do
        # cc self to history
        data_set_history.send(origin_table.singularize.foreign_key + '=', id)
        attributes.except('id', 'created_at', 'updated_at').each do |key, value|
          data_set_history.send("#{key}=", value)
        end
        data_set_history.is_part_of = parent_id if data_set_history.respond_to?('is_part_of')

        lower_bound = updated_at
        lower_bound = save_time if lower_bound > save_time
        data_set_history.history_valid = (lower_bound...save_time)
        data_set_history.deleted_at = Time.zone.now.to_s(:long_usec) if delete
        data_set_history.created_at = save_time
        data_set_history.updated_at = save_time
        data_set_history.save(touch: false)

        # cc classification_content to history
        classification_content.all.find_each do |item|
          classification_history = DataCycleCore::ClassificationContent::History.new
          classification_history.content_data_history_id = data_set_history.id
          classification_history.content_data_history_type = data_set_history.class.to_s
          item.attributes.except('id', 'content_data_id', 'content_data_type').each do |key, value|
            classification_history.send("#{key}=", value)
          end
          classification_history.classification_id = item.classification_id
          classification_history.save
        end

        # cc embedded data from other content tables
        embedded_relations.each do |content_name|
          content_relation = send(content_name[:name])
          content_relation.each_with_index do |content_item, index|
            new_content_history = content_item.to_history(save_time: save_time)
            content_one_data = [new_content_history.id, new_content_history.class.to_s, '', nil]
            content_two_data = [data_set_history.id, data_set_history.class.to_s, content_name[:name], index]
            content_relation_history_data = ['a', 'b'].map { |selector|
              [
                "content_#{selector}_history_id".to_sym,
                "content_#{selector}_history_type".to_sym,
                "relation_#{selector}".to_sym,
                "order_#{selector}".to_sym
              ]
            }.flatten
              .zip(content_name[:table] < origin_table ? content_one_data + content_two_data : content_two_data + content_one_data).to_h
            content_relation_history_data['history_valid'] = (content_item.updated_at...save_time)
            DataCycleCore::ContentContent::History.create!(content_relation_history_data)
          end
        end

        linked_relations.each do |content_name|
          content_relation = send(content_name[:name])
          content_relation.each_with_index do |content_item, index|
            content_one_data = [content_item.id, content_item.class.to_s, '', nil]
            content_two_data = [data_set_history.id, data_set_history.class.to_s, content_name[:name], index]
            content_relation_history_data = ['a', 'b'].map { |selector|
              [
                "content_#{selector}_history_id".to_sym,
                "content_#{selector}_history_type".to_sym,
                "relation_#{selector}".to_sym,
                "order_#{selector}".to_sym
              ]
            }.flatten
              .zip(content_name[:table] < origin_table ? content_one_data + content_two_data : content_two_data + content_one_data).to_h
            content_relation_history_data['history_valid'] = (content_item.updated_at...save_time)
            DataCycleCore::ContentContent::History.create!(content_relation_history_data)
          end
        end

        data_set_history.save
      end
      data_set_history
    end

    def delete_childs(delete_relation)
      embedded_property_names.each do |name|
        definition = property_definitions[name]

        delete = false
        # delete = definition['delete'] unless definition['delete'].blank?
        delete = true if is_history? || definition['type'] == 'embedded'

        relation_name = definition['linked_table']
        if delete
          load_embedded_objects(relation_name, name).each do |item|
            item.delete_childs(delete)
            item.destroy
          end
        else
          relation_class = is_history? ? DataCycleCore::ContentContent::History : DataCycleCore::ContentContent
          target_class = is_history? ? "DataCycleCore::#{relation_name.classify}::History" : "DataCycleCore::#{relation_name.classify}"
          content_one_data = [method(relation_name).call.ids, target_class, '']
          content_two_data = [id, self.class.to_s, name]
          where_hash = ['a', 'b'].map { |selector|
            if is_history?
              ["content_#{selector}_history_id".to_sym,
               "content_#{selector}_history_type".to_sym,
               "relation_#{selector}".to_sym]
            else
              ["content_#{selector}_id".to_sym,
               "content_#{selector}_type".to_sym,
               "relation_#{selector}".to_sym]
            end
          }.flatten
            .zip(relation_name < self.class.table_name ? content_one_data + content_two_data : content_two_data + content_one_data).to_h
          relations = relation_class.where(where_hash)
          relations.destroy_all unless relations.blank?
        end
      end

      # cleanup classification_relation (only if present item can be deleted)
      if delete_relation
        classification_property_names.each do |classification_name|
          content_relation = get_classification_relation(classification_name)
          content_relation.destroy_all unless content_relation.blank?
        end
      end
    end

    def validate(data)
      validator = DataCycleCore::MasterData::ValidateData.new
      validator.validate(data, schema)
    end

    def validate?(data, strict = false)
      validator = DataCycleCore::MasterData::ValidateData.new
      validator.valid?(data, schema, strict)
    end

    def set_search
      # upsert with one SQL Statement
      return if search_property_names.blank?

      full_text = search_property_names.map { |item| send(item) }.join(' ').gsub(/[']/, "''")
      full_text = '' if full_text.nil?
      full_text_most = (search_property_names - ['headline']).map { |item| send(item) }.join(' ').gsub(/[']/, "''")
      full_text_most = '' if full_text_most.nil?
      headline = try('send', 'headline')
      headline = headline.gsub(/[']/, "''") unless headline.nil?
      headline = '' if headline.nil?
      classification_string = display_classification_aliases.pluck(:name).try(:join, ' ').try(:gsub, /[']/, "''")
      classification_string = '' if classification_string.nil?
      all_text = [headline, classification_string, full_text].join(' ')
      validity_hash = metadata.nil? ? nil : metadata['validity_period']
      validity_string = get_validity(validity_hash)
      boost = schema['boost'] || 1.0

      connection = ActiveRecord::Base.connection
      sql_query = <<-EOS
        INSERT INTO searches (id, content_data_id, content_data_type, locale, words, full_text,
          created_at, updated_at, headline, classification_string, data_type, all_text, validity_period,boost)
        VALUES
        ( DEFAULT,
          '#{id}',
          '#{self.class}',
          '#{I18n.locale}',
          to_tsvector('simple', '#{full_text}'),
          '#{full_text_most}',
          '#{created_at}',
          '#{Time.zone.now.to_s(:long_usec)}',
          '#{headline}',
          '#{classification_string}',
          '#{template_name}',
          '#{all_text}',
          '#{validity_string}',
          #{boost}
        )
        ON CONFLICT (content_data_id, content_data_type, locale)
        WHERE content_data_id = '#{id}' AND content_data_type = '#{self.class}' AND locale = '#{I18n.locale}'
        DO UPDATE SET
          words = EXCLUDED.words,
          full_text = EXCLUDED.full_text,
          created_at = EXCLUDED.created_at,
          updated_at = EXCLUDED.updated_at,
          headline = EXCLUDED.headline,
          classification_string = EXCLUDED.classification_string,
          data_type = EXCLUDED.data_type,
          all_text = EXCLUDED.all_text,
          validity_period = EXCLUDED.validity_period,
          boost = EXCLUDED.boost;
      EOS
      connection.exec_query(ActiveRecord::Base.send(:sanitize_sql_for_conditions, sql_query))
    end

    def create_gpx
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.gpx(version: '1.1', creator: 'dataCycle', xmlns: 'http://www.topografix.com/GPX/1/1') do
          xml.metadata do
            xml.name title
            xml.desc ActionView::Base.full_sanitizer.sanitize(send('description')) if respond_to?('description')
            xml.time updated_at
            unless creator&.first&.name.blank?
              xml.author do
                xml.name creator&.first&.name
              end
            end
          end
          geo_properties.each do |key, value|
            geo = send(key)
            geo = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true).parse_wkt(geo) if geo.is_a?(String)

            if geo.try(:geometry_type) == RGeo::Feature::Point
              xml.wpt(lat: geo.y, lon: geo.x) do
                xml.name value['label']
                xml.ele geo.z if geo.z
              end
            elsif geo.try(:geometry_type) == RGeo::Feature::LineString
              xml.trk do
                xml.name value['label']
                xml.trkseg do
                  geo.points.each do |l|
                    xml.trkpt(lat: l.y, lon: l.x) do
                      xml.ele l.z if l.z
                    end
                  end
                end
              end
            end
          end
        end
      end

      builder.to_xml
    end

    def set_classification_with_children(classification_tree_label, classification_id, user)
      set_data_hash_attribute(classification_tree_label, [classification_id], user)
      children.each do |child|
        child.set_data_hash_attribute(classification_tree_label, [classification_id], user)
      end
    end

    def get_inherit_datahash(parent)
      data_hash = get_data_hash

      I18n.with_locale(parent.first_available_locale) do
        parent_data_hash = parent.get_data_hash

        DataCycleCore.inheritable_attributes.each do |attribute_key|
          data_hash[attribute_key] = parent_data_hash[attribute_key] if parent_data_hash[attribute_key].present?
        end

        data_hash[DataCycleCore.features.dig(:life_cycle, :attribute_key)] = parent_data_hash[DataCycleCore.features.dig(:life_cycle, :attribute_key)] if DataCycleCore.features.dig(:life_cycle)
      end

      data_hash.compact!
    end

    private

    def get_classification_relation(relation_name)
      if is_history?
        classification_object = DataCycleCore::ClassificationContent::History
        where_hash = { 'content_data_history_id' => id, 'content_data_history_type' => self.class.to_s, 'relation' => relation_name }
      else
        classification_object = DataCycleCore::ClassificationContent
        where_hash = { 'content_data_id' => id, 'content_data_type' => self.class.to_s, 'relation' => relation_name }
      end
      classification_object.where(where_hash)
    end

    def get_asset_relation(relation_name)
      asset_content_object = DataCycleCore::AssetContent
      where_hash = { 'content_data_id' => id, 'content_data_type' => self.class.to_s, 'relation' => relation_name }
      asset_content_object.where(where_hash)
    end

    def set_relation_ids(ids, relation_name, tree_label, default_value)
      if is_blank?(ids)
        begin
          if !default_value.blank? && ids.nil? && get_classification_relation(relation_name).count.zero?
            classification_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
              .where('classification_tree_labels.name = ?', tree_label)
              .where('classification_aliases.name = ?', default_value).first!.id
            DataCycleCore::ClassificationContent
              .find_or_create_by(
                'content_data_id' => id,
                'content_data_type' => self.class.to_s,
                classification_id: classification_id,
                relation: relation_name
              )
            ids = [classification_id]
          elsif !default_value.blank? && ids.nil?
            ids = get_classification_relation(relation_name).pluck(:classification_id)
          end
        rescue ActiveRecord::RecordNotFound => e
          logger.error "Missing default value '#{default_value}' for attribute '#{relation_name}'"
          raise e
        end
      else
        # insert missing ids
        ids.each do |classification_id_value|
          DataCycleCore::ClassificationContent
            .find_or_create_by(
              'content_data_id' => id,
              'content_data_type' => self.class.to_s,
              classification_id: classification_id_value,
              relation: relation_name
            )
        end
      end

      ids = [] if ids.blank? && default_value.blank?
      # delete missing ids
      found_ids = get_classification_relation(relation_name).pluck(:classification_id)
      to_delete = found_ids - ids
      unless to_delete.empty?
        DataCycleCore::ClassificationContent
          .where(
            'content_data_id' => id,
            'content_data_type' => self.class.to_s,
            classification_id: to_delete,
            relation: relation_name
          ).destroy_all
      end
    end

    def set_asset_id(id, relation_name, asset_type)
      unless id.blank?
        DataCycleCore::AssetContent
          .find_or_create_by(
            'content_data_id' => self.id,
            'content_data_type' => self.class.to_s,
            asset_id: id,
            asset_type: asset_type,
            relation: relation_name
          )
      end

      # delete old id
      found_ids = get_asset_relation(relation_name).pluck(:asset_id)
      to_delete = found_ids - [id]

      unless to_delete.empty?
        DataCycleCore::AssetContent
          .where(
            'content_data_id' => self.id,
            'content_data_type' => self.class.to_s,
            asset_id: to_delete,
            asset_type: asset_type,
            relation: relation_name
          ).destroy_all
      end
    end

    def set_template_data_hash(data_hash, properties, save_time, current_user)
      properties.each do |key, value|
        storage_cases_set(key, data_hash[key], value, save_time, current_user)
      end
    end

    def storage_cases_set(key, value, properties, save_time, current_user)
      case properties['type']
      when 'linked'
        set_linked_data_type(key, value, properties['linked_table'], properties['template_name'], false, save_time, current_user)
      when 'embedded'
        # delete = false
        # delete = true if properties.key?('delete') && properties['delete'] == true
        set_linked_data_type(key, value, properties['linked_table'], properties['template_name'], true, save_time, current_user)
      when 'string', 'number', 'datetime', 'boolean', 'geographic', 'object'
        save_values(key, value, properties)
      when 'classification'
        set_relation_ids(value, key, properties['tree_label'], properties['default_value'])
      when 'asset'
        set_asset_id(value, key, properties['type_name'])
      when 'key'
        # do nothing
        true
      else
        puts "wrong data_type #{key} | #{value}"
      end
    end

    def save_values(key, value, properties)
      case properties['storage_location']
      when 'column'
        method("#{key}=").call(value)
      when 'value'
        save_to_jsonb(key, value, properties, 'metadata')
      when 'translated_value'
        save_to_jsonb(key, value, properties, 'content')
      end
    end

    def save_to_jsonb(key, data, properties, location)
      # parse tree in json, to only set data specified in the data definitions
      data = set_data_tree_hash(data, properties['properties'], location) if properties['type'] == 'object' && data.is_a?(::Hash) # object with potentially relevant data

      # dont overwrite creator with empty values
      return if key == 'creator' && data.nil?

      # set to json field (could be empty)
      if method(location.to_s).call.blank?
        method("#{location}=").call({ key => data })
      else
        method(location.to_s).call.method('[]=').call(key, data)
      end
    end

    def set_data_tree_hash(data, data_definitions, location)
      data_hash = {}
      return if data.blank?
      data_definitions.each_key do |key|
        if data_definitions[key]['type'] == 'object'
          data_hash[key] = set_data_tree_hash(data[key], data_definitions[key]['properties'], location)
        elsif (data_definitions[key]['storage_location'] == 'value' && location == 'metadata') || (data_definitions[key]['storage_location'] == 'translated_value' && location == 'content')
          data_hash[key] = data[key] # TODO: if necessary make data casts here!!
        elsif data_definitions[key]['storage_location'] == 'column'
          method("#{key}=").call(data[key])
        end
      end
      data_hash
    end

    def get_embeddedlink_hash(field_name, table)
      if table < self.class.table_name
        {
          content_b_id: id,
          content_b_type: self.class.to_s,
          relation_b: field_name
        }
      else
        {
          content_a_id: id,
          content_a_type: self.class.to_s,
          relation_a: field_name
        }
      end
    end
    ############################################################################

    def set_linked_data_type(field_name, input_data, table, name, delete, save_time, current_user)
      updated_item_keys = []

      selector = table < self.class.table_name
      data = input_data.dup

      data = data.ids if data.is_a?(ActiveRecord::Relation)
      # for embeddedLinkArray transform data
      if data.is_a?(::Array) && !data.blank? && data.first.is_a?(::String)
        data.map! { |item| { 'id' => item } }
      end

      unless is_blank?(data)
        old_relations = get_relation(field_name, table)
        data.each_index do |index|
          item = data[index]
          if item.key?('id') && item['id'].present?
            # relation update/insert
            upsert_relation = DataCycleCore::ContentContent.find_or_create_by(
              get_relation_data_hash(field_name, table, item['id'])
            )
            upsert_relation.send(selector ? 'order_b='.to_sym : 'order_a='.to_sym, index)
            upsert_relation.save
            if item.keys.count > 1 # update actual data
              update_item = ('DataCycleCore::' + table.classify).constantize.find_by(id: item['id'])
              update_item.set_data_hash(data_hash: item, current_user: current_user, save_time: save_time, prevent_history: true)
              update_item.save
            end
            updated_item_keys.push(item['id']) # remember updated id
          else # insert new data
            template = ('DataCycleCore::' + table.classify).constantize
              .find_by(template: true, template_name: name)
            insert_item = ('DataCycleCore::' + table.classify).constantize.new
            insert_item.schema = template.schema
            insert_item.template_name = template.template_name
            insert_item.save
            insert_item.set_data_hash(data_hash: item.merge({ 'is_part_of' => id }), current_user: current_user, save_time: save_time, prevent_history: true)
            insert_item.save
            updated_item_keys.push(insert_item.id) # remember inserted id

            # insert_relation
            order_hash = selector ? { order_a: nil, order_b: index } : { order_a: index, order_b: nil }
            DataCycleCore::ContentContent.create!(
              get_relation_data_hash(field_name, table, insert_item.id).merge(order_hash)
            )
          end
        end
      end

      available_update_item_keys = send(field_name).ids
      potentially_delete = available_update_item_keys - updated_item_keys

      if delete
        # full access to embeddedObjects
        potentially_delete.each do |key|
          item = ('DataCycleCore::' + table.classify).constantize.find_by(id: key)
          translations = item.translated_locales
          if (translations - [I18n.locale]).empty?
            # destroy relationObject + additional embeddedObjects and their relations
            to_update_item = method(table).call.find_by(id: key)
            # check for subtrees
            to_update_item.delete_childs(delete)
            to_update_item.destroy
          else
            # only destroy particular translation !
            item.translation.destroy
          end
        end
      else
        # only destroy relations (independend of how many translations in self/embeddedObject exist)
        potentially_delete.each do |key|
          DataCycleCore::ContentContent
            .find_by(get_relation_data_hash(field_name, table, key))
            .destroy
        end
      end
      method(table).call.reload # MO: force reload of the relation, otherwise cached data can obscure the next get_data_hash
    end

    def get_relation(field_name, table)
      if table < self.class.table_name
        content_content_b.where(relation_b: field_name)
      else
        content_content_a.where(relation_a: field_name)
      end
    end

    def get_relation_data_hash_order(field_name, table, item_id, order)
      item_data = [item_id, "DataCycleCore::#{table.classify}", '', nil]
      self_data = [id, self.class.to_s, field_name, order]
      ['a', 'b'].map { |selector|
        ["content_#{selector}_id".to_sym, "content_#{selector}_type".to_sym, "relation_#{selector}".to_sym, "order_#{selector}".to_sym]
      }.flatten
        .zip(table < self.class.table_name ? item_data + self_data : self_data + item_data).to_h
    end

    def get_relation_data_hash(field_name, table, item_id)
      item_data = [item_id, "DataCycleCore::#{table.classify}", '']
      self_data = [id, self.class.to_s, field_name]
      ['a', 'b'].map { |selector|
        ["content_#{selector}_id".to_sym, "content_#{selector}_type".to_sym, "relation_#{selector}".to_sym]
      }.flatten
        .zip(table < self.class.table_name ? item_data + self_data : self_data + item_data).to_h
    end

    # validate nil,"",[],{},[nil],[""] as blank.
    def is_blank?(data)
      return true if data.blank?
      if data.is_a?(::Array)
        return true if data.length == 1 && data[0].blank?
      end
      false
    end

    def get_validity(validity_hash)
      from, to = get_validity_values validity_hash
      [
        '[',
        from.is_a?(DateTime) ? from.to_s(:long_usec) : '',
        ',',
        to.is_a?(DateTime) ? to.to_s(:long_usec) : '',
        ']'
      ].join('')
    end

    def get_validity_values(validity_hash)
      from = nil
      to = nil
      from = validity_hash['date_published'] || validity_hash['valid_from'] if validity_hash && (validity_hash['date_published'] || validity_hash['valid_from'])
      to = validity_hash['expires'] || validity_hash['valid_until'] if validity_hash && (validity_hash['expires'] || validity_hash['valid_until'])

      from = from.blank? ? nil : from.to_datetime
      from = nil if !from.blank? && from < DateTime.new(1980, 1, 1, 0, 0)
      to = to.blank? ? nil : to.to_datetime
      to = nil if !to.blank? && to > DateTime.new(9999, 1, 1, 0, 0)

      [from, to]
    end
  end
end
