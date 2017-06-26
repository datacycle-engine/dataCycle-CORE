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
          set_template_data_hash(template_hash['properties'], data_hash)
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

    def set_template_data_hash(properties, data_hash)
      properties.each do |key,value|
        storage_cases_set(key, data_hash[key], properties[key])
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



  end
end
