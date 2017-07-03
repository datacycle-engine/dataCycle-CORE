module DataCycleCore
  class DataHash < ApplicationRecord

    self.abstract_class = true

    # get data as specified in the data template
    # data hash with keys named as in schema.org
    def get_data_hash
      if translated_locales.include?(I18n.locale) || changes.count > 0 # for new data-sets with pending data in it
        data_type = metadata['validation']
        data_hash = {}
        data_type['properties'].each do |key,value|
          next if key == '@id'
          data_hash[key] = storage_cases_get(key,data_type['properties'][key])
        end
        data_hash
      else
        return nil
      end
    end

    # set data as specified in the data template
    # data hash with keys named as in schema.org
    def set_data_hash(data_hash)
      template_hash = metadata['validation']
      if validate?(data_hash)
        ActiveRecord::Base.transaction do
          set_template_data_hash(data_hash, template_hash['properties'])
        end
      end
      validate(data_hash) # return error/warnings from validation
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

    private

    def get_relation_ids(storage_type, tree_label)
      class_string = "DataCycleCore::"+storage_type.classify
      class_id = self.class.to_s.demodulize.foreign_key
      class_string.constantize.
        where(class_id => id).
        joins(classification: [classification_groups: [classification_alias: [classification_trees: [:classification_tree_label]]]]).
        where("classification_tree_labels.name = ?", tree_label).
        pluck(:classification_id)
    end

    def set_relation_ids(storage_type, ids, tree_label)
      return if ids.nil?
      class_string = "DataCycleCore::"+storage_type.classify
      class_id = self.class.to_s.demodulize.foreign_key

      # insert missing ids
      ids.each do |classification_id|
        class_string.constantize.
          find_or_create_by(
            class_id => self.id,
            classification_id: classification_id
          )
      end
      # delete missing ids
      found_ids = get_relation_ids(storage_type, tree_label)
      to_delete = found_ids - ids
      if to_delete.size > 0
        class_string.constantize.
          where(
            class_id => self.id,
            classification_id: to_delete
          ).destroy_all
      end
    end

    def set_template_data_hash(data_hash, properties)
      properties.each do |key,value|
        #puts " key ----> #{key} | value: #{value} || #{data_hash[key]} | #{data_hash}"
        storage_cases_set(key, data_hash[key], value)
      end
    end

    def storage_cases_get(key, properties)
      case properties["storage_location"]
      when "column"
        self.method(key).call
      when "content"
        self.content[key]
      when "metadata"
        self.metadata[key]
      when "properties"
        self.properties[key]
      when "classification_relation"
        get_relation_ids(properties["storage_type"], properties["type_name"])
      when "key"
        self.id
      else
        get_linked_data_type(properties['storage_location'], properties['name'], properties['description'])
      end
    end

    def storage_cases_set(key, value, properties)
      #puts " key ----> #{key} | value: #{value} | #{properties}"
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
        set_relation_ids(properties['storage_type'], value, properties['type_name'])
      else
        # maybe already evaluated with validations?
        unless properties['storage_location'] == 'key'
          if properties.has_key?('name') && properties.has_key?('description')
            # puts "object is stored in other table - a linked data_type --> #{key} | #{value}"
            set_linked_data_type(value, properties['storage_location'], properties['name'], properties['description'])
          else
            puts "wrong data_type #{key} | #{value}"
          end
        end
      end
    end

    def save_to_jsonb(key, data, properties, location)
      # parse tree in json, to only set data specified in the data definitions
      if data.is_a?(::Hash)
        data = set_data_tree_hash(data, properties['properties'])
      end
      # set to json field (could be empty)
      if self.method("#{location}").call.blank?
        self.method("#{location}=").call({ key => data })
      else
        self.method("#{location}").call.method("[]=").call(key,data)
      end
    end

    def set_data_tree_hash(data, data_definitions)
      data_hash = {}
      return if data.blank?
      data_definitions.each do |key,value|
        unless data_definitions[key]['type'] == 'object'
          data_hash[key] = data[key]
        else
          data_hash[key] = set_data_tree_hash(data[key], data_definitions[key]['properties'])
        end
      end
      data_hash
    end

    def get_linked_data_type(table, name, description)
      return_data = []
      self.method(table).call.each do |item|
        return_data.push(item.get_data_hash.merge({'id' => item.id}))
      end
      return_data.compact
    end

    def set_linked_data_type(data, table, name, description)
      # figure out the relation name (alphabetic order from this_class + table )
      tables = [ table, self.class.table_name ].sort
      relation = tables[0].singularize+"_"+tables[1]

      # get validation template
      template = ("DataCycleCore::"+table.classify).constantize.
        find_by(template: true, headline: name, description: description)

      updated_item_keys = []

      unless is_blank?(data)
        # update/insert linked_data
        data.each do |item|
          if item.has_key?('id') && item.keys.count == 1
            # id is the only item --> no update
            updated_item_keys.push(item['id'])

            # relation update/insert
            upsert_relation = ("DataCycleCore::"+relation.classify).
              constantize.
              find_or_create_by(
                self.class.table_name.singularize.foreign_key.to_sym => self.id,
                table.singularize.foreign_key.to_sym => item['id']
                )
            upsert_relation.save

          elsif item.has_key?('id') && !item['id'].blank?
            # update
            update_item = ("DataCycleCore::"+table.classify).constantize.find_by(id: item['id'])
            update_item.set_data_hash(item)
            update_item.save
            updated_item_keys.push(update_item.id)
          else
            # insert
            insert_item = ("DataCycleCore::"+table.classify).constantize.new
            insert_item.metadata = { 'validation' => template.metadata['validation'] }
            insert_item.save
            insert_item.set_data_hash(item)
            insert_item.save
            updated_item_keys.push(insert_item.id)

            # insert_relation
            insert_relation = ("DataCycleCore::"+relation.classify).constantize.new
            insert_relation.method(self.class.table_name.singularize.foreign_key+"=").call(self.id)
            insert_relation.method(table.singularize.foreign_key+"=").call(insert_item.id)
            insert_relation.save
          end
        end
      end
      # check if items in context of the present language should be deleted
      available_update_item_keys = self.method(table).call.ids
      potentially_delete = available_update_item_keys - updated_item_keys

      potentially_delete.each do |key|
        item = ("DataCycleCore::"+table.classify).constantize.find_by(id: key)
        translations = item.translated_locales
        if (translations-[ I18n.locale ]).size < 1
          # find relation and destroy it
          self.method(table).call.find_by(id: key).destroy
          ("DataCycleCore::"+relation.classify).constantize.
            find_by(self.class.table_name.singularize.foreign_key.to_sym => self.id, table.singularize.foreign_key.to_sym => key).
            destroy
        else
          # only destroy particular translation !
          item.translation.destroy
        end
      end
      self.method(table).call.reload # MO: force reload of the relation, otherwise cached data can obsure the next get_data_hash
    end

    # validate nil,"",[],[nil],[""] as blank.
    def is_blank?(data)
      return true if data.blank?
      if data.is_a?(::Array)
        return true if data.length == 1 && data[0].blank?
      end
      return false
    end

  end
end
