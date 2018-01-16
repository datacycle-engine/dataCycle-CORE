module DataCycleCore
  class DataHash < Content

    self.abstract_class = true

    # get data as specified in the data template
    # data hash with keys named as in schema.org
    def get_data_hash(timestamp = Time.zone.now)
      if translated_locales.include?(I18n.locale) || changes.count > 0 # for new data-sets with pending data in it
        data_hash = self.as_of(timestamp).to_h(timestamp)
        data_hash = merge_release(data_hash, release) if kind_of?(DataCycleCore::Releasable)
        return data_hash
      else
        return nil
      end
    end

    # set data as specified in the data template
    # data hash with keys named as in schema.org
    def set_data_hash(data_hash:, current_user: nil, save_time: Time.zone.now, prevent_history: false)
      stripped_data_hash = data_hash
      stripped_data_hash, global_release_hash = extract_release(data_hash, true) if kind_of?(DataCycleCore::Releasable) # strip also release data from embeddedObjects

      if validate?(stripped_data_hash)
        ActiveRecord::Base.transaction do
          self.to_history(save_time: save_time) if self.id.nil? == false && prevent_history == false
          data_hash, release_hash = extract_release(data_hash, false) if kind_of?(DataCycleCore::Releasable) # strip release data only from this object
          set_template_data_hash(data_hash, property_definitions, save_time, current_user)
          if kind_of?(DataCycleCore::Releasable)
            self.release = release_hash
            self.release_id = set_global_release(global_release_hash)
          end
          self.updated_at = save_time
          updated_by = {'last_updated_by' => current_user.try(:id)}
          self.metadata.nil? ? self.metadata = updated_by : self.metadata.merge!(updated_by)
          self.save if self.id.nil?
          self.set_search
        end
      end
      validate(stripped_data_hash) # return error/warnings from validation
    end

    def destroy_content
      self.to_history(save_time: Time.zone.now, delete: true) unless is_history?
      self.delete_childs(true)
    end

    def set_data_hash_attribute(key, value, current_user, save_time = Time.zone.now)
      key_hash = metadata.dig('validation', 'properties', key)
      unless key_hash.nil?
        ActiveRecord::Base.transaction do
          storage_cases_set(key, value, key_hash, save_time, current_user)
        end
      end
    end

    def to_history(save_time:, parent_id: nil, delete: false)
      origin_table = self.class.to_s.split("::")[1].tableize
      data_set_history = (self.class.to_s + "::History").safe_constantize.new

      ActiveRecord::Base.transaction do

        # cc self to history
        data_set_history.send(origin_table.singularize.foreign_key+"=", self.id)
        self.attributes.except("id", "created_at").each do |key,value|
          data_set_history.send("#{key}=", value)
        end
        data_set_history.is_part_of = parent_id if data_set_history.respond_to?('is_part_of')

        lower_bound = self.updated_at
        if lower_bound > save_time
          lower_bound = save_time
        end
        data_set_history.history_valid = (lower_bound ... save_time)
        data_set_history.deleted_at = Time.zone.now.to_s(:long_usec) if delete

        data_set_history.save

        # cc classification_content to history
        self.classification_content.all.each do |item|
          classification_history = DataCycleCore::ClassificationContent::History.new
          classification_history.content_data_history_id = data_set_history.id
          classification_history.content_data_history_type = data_set_history.class.to_s
          item.attributes.except('id', 'content_data_id', 'content_data_type').each do |key,value|
            classification_history.send("#{key}=", value)
          end
          classification_history.classification_id = item.classification_id
          classification_history.save
        end

        # cc embedded data from other content tables
        embedded_relations.each do |content_name|
          self.send(content_name[:name]).each do |content_item|
            new_content_history = content_item.to_history(save_time: save_time)
            content_one_data = [new_content_history.id, new_content_history.class.to_s, '']
            content_two_data = [data_set_history.id, data_set_history.class.to_s, content_name[:name]]
            content_relation_history_data = ['a', 'b'].map { |selector|
              [ "content_#{selector}_history_id".to_sym,
                "content_#{selector}_history_type".to_sym,
                "relation_#{selector}".to_sym]
            }.flatten
              .zip(content_name[:table] < origin_table ?
                content_one_data+content_two_data :
                content_two_data+content_one_data
              ).to_h
            content_relation_history_data["history_valid"] = (content_item.updated_at ... save_time)
            DataCycleCore::ContentContent::History.create!(content_relation_history_data)
          end
        end

        linked_relations.each do |content_name|
          self.send(content_name[:name]).each do |content_item|
            content_one_data = [content_item.id, content_item.class.to_s, '']
            content_two_data = [data_set_history.id, data_set_history.class.to_s, content_name[:name]]
            content_relation_history_data = ['a', 'b'].map { |selector|
              [ "content_#{selector}_history_id".to_sym,
                "content_#{selector}_history_type".to_sym,
                "relation_#{selector}".to_sym]
            }.flatten
              .zip(content_name[:table] < origin_table ?
                content_one_data+content_two_data :
                content_two_data+content_one_data
              ).to_h
            content_relation_history_data["history_valid"] = (content_item.updated_at ... save_time)
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
        delete = definition['delete'] unless definition['delete'].blank?
        delete = true if is_history?

        relation_name = definition['storage_location']
        if delete
          load_embedded_objects(relation_name, name).each do |item|
            item.delete_childs(delete)
            item.destroy
          end
        else
          relation_class = is_history? ? DataCycleCore::ContentContent::History : DataCycleCore::ContentContent
          target_class = is_history? ? "DataCycleCore::#{relation_name.classify}::History" : "DataCycleCore::#{relation_name.classify}"
          content_one_data = [self.method(relation_name).call.ids, target_class, '']
          content_two_data = [self.id, self.class.to_s, name]
          where_hash = ['a', 'b'].map { |selector|
            if is_history?
              [ "content_#{selector}_history_id".to_sym,
                "content_#{selector}_history_type".to_sym,
                "relation_#{selector}".to_sym]
            else
              [ "content_#{selector}_id".to_sym,
                "content_#{selector}_type".to_sym,
                "relation_#{selector}".to_sym]
            end
          }.flatten
            .zip(relation_name < self.class.table_name ?
              content_one_data+content_two_data :
              content_two_data+content_one_data
            ).to_h

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
      template_hash = metadata["validation"]
      validator = DataCycleCore::MasterData::ValidateData.new
      validator.validate(data, template_hash)
    end

    def validate?(data, strict = false)
      template_hash = metadata['validation']
      validator = DataCycleCore::MasterData::ValidateData.new
      validator.valid?(data, template_hash, strict)
    end

    def set_search
      # upsert with one SQL Statement
      if search_property_names.blank?
        return
      end

      full_text = search_property_names.map{|item| self.send(item)}.join(' ').gsub(/[']/,"''")
      full_text = "" if full_text.nil?
      full_text_most = (search_property_names - ['headline']).map{|item| self.send(item)}.join(' ').gsub(/[']/,"''")
      full_text_most = "" if full_text_most.nil?
      headline = self.try('send','headline')
      headline = headline.gsub(/[']/,"''") unless headline.nil?
      headline = "" if headline.nil?
      classification_string = self.display_classification_aliases.pluck(:name).try(:join, " ").try(:gsub, /[']/, "''")
      classification_string = "" if classification_string.nil?
      all_text = [headline, classification_string, full_text].join(' ')
      validity_hash = metadata.nil? ? nil : metadata['validity_period']
      validity_string = get_validity(validity_hash)
      boost = self.metadata['validation']['boost'] || 1.0

      connection = ActiveRecord::Base.connection
      sql_query = <<-eos
        INSERT INTO searches (id, content_data_id, content_data_type, locale, words, full_text,
          created_at, updated_at, headline, classification_string, data_type, all_text, validity_period,boost)
        VALUES
        ( DEFAULT,
          '#{self.id}',
          '#{self.class.to_s}',
          '#{I18n.locale}',
          to_tsvector('simple', '#{full_text}'),
          '#{full_text_most}',
          '#{self.created_at}',
          '#{Time.zone.now.to_s(:long_usec)}',
          '#{headline}',
          '#{classification_string}',
          '#{self.metadata.try(:[],'validation').try(:[],'name')}',
          '#{all_text}',
          '#{validity_string}',
          #{boost}
        )
        ON CONFLICT (content_data_id, content_data_type, locale)
        WHERE content_data_id = '#{self.id}' AND content_data_type = '#{self.class.to_s}' AND locale = '#{I18n.locale}'
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
      eos
      connection.exec_query(sql_query)
    end

    private

    def get_classification_relation(relation_name)
      if is_history?
        classification_object = DataCycleCore::ClassificationContent::History
        where_hash = {"content_data_history_id" => id, "content_data_history_type" => self.class.to_s, "relation" => relation_name}
      else
        classification_object = DataCycleCore::ClassificationContent
        where_hash = {"content_data_id" => id, "content_data_type" => self.class.to_s, "relation" => relation_name}
      end
      classification_object.where(where_hash)
    end

    def set_relation_ids(ids, relation_name, tree_label, default_value)
      if is_blank?(ids)
        begin
          if !default_value.blank? && ids.nil? && get_classification_relation(relation_name).count == 0
            classification_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
                .where("classification_tree_labels.name = ?", tree_label)
                .where("classification_aliases.name = ?", default_value).first!.id
            DataCycleCore::ClassificationContent.
              find_or_create_by(
                "content_data_id" => self.id,
                "content_data_type" => self.class.to_s,
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
        ids.each do |classification_id|
          DataCycleCore::ClassificationContent.
            find_or_create_by(
              "content_data_id" => self.id,
              "content_data_type" => self.class.to_s,
              classification_id: classification_id,
              relation: relation_name
            )
        end
      end

      ids = [] if ids.blank? && default_value.blank?
      # delete missing ids
      found_ids = get_classification_relation(relation_name).pluck(:classification_id)
      to_delete = found_ids - ids
      if to_delete.size > 0
        DataCycleCore::ClassificationContent.
          where(
            "content_data_id" => self.id,
            "content_data_type" => self.class.to_s,
            classification_id: to_delete,
            relation: relation_name
          ).destroy_all
      end
    end

    def set_template_data_hash(data_hash, properties, save_time, current_user)
      properties.each do |key,value|
        storage_cases_set(key, data_hash[key], value, save_time, current_user)
      end
    end

    def storage_cases_set(key, value, properties, save_time, current_user)
      if properties['type'] == 'embeddedLinkArray' || properties['type'] == 'embeddedLink'
        set_linked_data_type(key, value, properties['type_name'], key, properties['type_name'].classify, false, save_time, current_user)
      else
        case properties['storage_location']
        when 'column'
          self.method("#{key}=").call(value)
        when 'content'
          save_to_jsonb(key, value, properties, 'content')
        when 'metadata'
          save_to_jsonb(key, value, properties, 'metadata')
        when 'properties'
          save_to_jsonb(key, value, properties, 'properties')
        when 'classification_relation'
          set_relation_ids(value, key, properties['type_name'], properties['default_value'])
        else
          unless properties['storage_location'] == 'key'  # do nothing with key
            if properties.has_key?('name') && properties.has_key?('description')
              delete = false
              delete = true if properties.has_key?('delete') && properties['delete'] == true
              set_linked_data_type(key, value, properties['storage_location'], properties['name'], properties['description'], delete, save_time, current_user)
            else
              puts "wrong data_type #{key} | #{value}"
            end
          end
        end
      end
    end

    def save_to_jsonb(key, data, properties, location)
      # parse tree in json, to only set data specified in the data definitions
      if properties['type'] == 'object' && data.is_a?(::Hash) # object with potentially relevant data
        data = set_data_tree_hash(data, properties['properties'], location)
      end

      # dont overwrite creator with empty values
      return if key == "creator" && data.nil?

      # set to json field (could be empty)
      if self.method("#{location}").call.blank?
        self.method("#{location}=").call({ key => data })
      else
        self.method("#{location}").call.method("[]=").call(key,data)
      end
    end

    def set_data_tree_hash(data, data_definitions, location)
      #ap data_definitions
      data_hash = {}
      return if data.blank?
      data_definitions.each do |key,value|
        if data_definitions[key]['type'] == 'object'
          data_hash[key] = set_data_tree_hash(data[key], data_definitions[key]['properties'], location)
        elsif data_definitions[key]['storage_location'] == location
          data_hash[key] = data[key]
        elsif data_definitions[key]['storage_location'] == 'column'
          self.method("#{key}=").call(data[key])
        else
          #ignore wrong data
        end
      end
      data_hash
    end

    def set_linked_data_type(field_name, data, table, name, description, delete, save_time, current_user)
      relation = "content_contents"
      updated_item_keys = []

      # for embeddedLink and embeddedLinkArray transform data
      if data.kind_of?(::Array) && !data.blank? && data.first.kind_of?(::String)
        data.map!{|item| {"id" => item} }
      elsif data.kind_of?(::String) && !data.blank?
        data = [{"id" => data}]
      end

      unless is_blank?(data)
        # update/insert linked_data
        data.each do |item|
          if item.has_key?('id') && !item['id'].blank? && item.keys.count == 1
            #puts "id is the only item --> no update"
            updated_item_keys.push(item['id'])
            # relation update/insert
            upsert_relation = DataCycleCore::ContentContent.find_or_create_by(
              get_relation_data_hash(field_name, table, item['id'])
            )
            upsert_relation.save
          elsif item.has_key?('id') && !item['id'].blank?
            #puts "update"
            update_item = ("DataCycleCore::"+table.classify).constantize.find_by(id: item['id'])
            update_item.set_data_hash(data_hash: item, current_user: current_user, save_time: save_time, prevent_history: true)
            update_item.save
            updated_item_keys.push(update_item.id)
          else
            #puts "insert"

            # get validation template
            template = ("DataCycleCore::"+table.classify).constantize
              .with_translations('de')
              .find_by("template = true AND metadata->'validation'->>'name' = ? AND metadata->'validation'->>'description' = ?", name,  description )

            insert_item = ("DataCycleCore::"+table.classify).constantize.new
            insert_item.metadata = { 'validation' => template.metadata['validation'] }
            insert_item.save
            insert_item.set_data_hash(data_hash: item.merge({"is_part_of" => self.id}), current_user: current_user, save_time: save_time, prevent_history: true)
            insert_item.save
            updated_item_keys.push(insert_item.id)

            # insert_relation
            DataCycleCore::ContentContent.create!(
              get_relation_data_hash(field_name, table, insert_item.id)
            )
          end
        end
      end

      available_update_item_keys = self.send(field_name).ids
      potentially_delete = available_update_item_keys - updated_item_keys

      if delete
        # full access to embeddedObjects
        potentially_delete.each do |key|
          item = ("DataCycleCore::"+table.classify).constantize.find_by(id: key)
          translations = item.translated_locales
          if (translations-[ I18n.locale ]).size < 1
            # destroy relationObject + additional embeddedObjects and their relations
            to_update_item = self.method(table).call.find_by(id: key)
            #check for subtrees
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
          DataCycleCore::ContentContent.
            find_by(get_relation_data_hash(field_name, table, key)).
            destroy
        end
      end
      self.method(table).call.reload # MO: force reload of the relation, otherwise cached data can obsure the next get_data_hash
    end

    def get_relation_data_hash(field_name, table, item_id)
      item_data = [item_id, "DataCycleCore::#{table.classify}", ""]
      self_data = [self.id, self.class.to_s, field_name]
      ['a', 'b'].map { |selector|
        ["content_#{selector}_id".to_sym, "content_#{selector}_type".to_sym, "relation_#{selector}".to_sym]
      }.flatten
      .zip(table < self.class.table_name ? item_data+self_data : self_data+item_data).to_h
    end

    # validate nil,"",[],{},[nil],[""] as blank.
    def is_blank?(data)
      return true if data.blank?
      if data.is_a?(::Array)
        return true if data.length == 1 && data[0].blank?
      end
      return false
    end

    def get_validity(validity_hash)
      from, to = get_validity_values validity_hash
      [
        '[',
        from.kind_of?(DateTime) ? from.to_s(:long_usec) : '',
        ',',
        to.kind_of?(DateTime) ? to.to_s(:long_usec) : '',
        ']'
      ].join('')
    end

    def get_validity_values(validity_hash)
      from, to = nil, nil
      if validity_hash && (validity_hash['date_published'] || validity_hash['valid_from'])
        from = validity_hash['date_published'] || validity_hash['valid_from']
      end
      if validity_hash && (validity_hash['expires'] || validity_hash['valid_until'])
        to = validity_hash['expires'] || validity_hash['valid_until']
      end

      from = from.blank? ? nil : from.to_datetime
      from = nil if !from.blank? && from < DateTime.new(1980,1,1,0,0)
      to = to.blank? ? nil : to.to_datetime
      to = nil if !to.blank? && to > DateTime.new(9999,1,1,0,0)

      [from, to]
    end

  end
end
