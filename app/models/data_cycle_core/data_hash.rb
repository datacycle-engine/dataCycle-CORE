module DataCycleCore
  class DataHash < Content

    self.abstract_class = true

    # get data as specified in the data template
    # data hash with keys named as in schema.org
<<<<<<< 67c44807463a4811b6c8826f9b398dddd2c62b92
    def get_data_hash
      locale = self.translated_locales.include?(I18n.locale) ? I18n.locale : self.translated_locales.first
      I18n.with_locale(locale) do
=======
    def get_data_hash(timestamp = Time.zone.now)
      if translated_locales.include?(I18n.locale) || changes.count > 0 # for new data-sets with pending data in it
        data_type = metadata['validation']
        #data_hash = get_template_data_hash(data_type['properties'])
        data_object = self.as_of(timestamp)
        #puts "#{data_object.class} // #{timestamp.class}: #{timestamp.to_s(:long_usec)}"
        data_hash = data_object.to_h(timestamp)
>>>>>>> history wired to get_data_hash, set_data_hash

        if translated_locales.include?(locale) || changes.count > 0 # for new data-sets with pending data in it
          data_type = metadata['validation']
          # data_hash = get_template_data_hash(data_type['properties'])
          data_hash = self.to_h

          data_hash = merge_release(data_hash, release) if kind_of?(DataCycleCore::Releasable)
          return data_hash
        else
          return nil
        end
      end
    end

    # set data as specified in the data template
    # data hash with keys named as in schema.org
    def set_data_hash(data_hash, save_time = Time.zone.now)
      template_hash = metadata['validation']

      stripped_data_hash = data_hash
      stripped_data_hash, global_release_hash = extract_release(data_hash, true) if kind_of?(DataCycleCore::Releasable) # strip also release data from embeddedObjects

      if validate?(stripped_data_hash)
        ActiveRecord::Base.transaction do
          self.to_history(save_time) unless self.id.nil?
          data_hash, release_hash = extract_release(data_hash, false) if kind_of?(DataCycleCore::Releasable) # strip release data only from this objectt
          set_template_data_hash(data_hash, template_hash['properties'], save_time)
          if kind_of?(DataCycleCore::Releasable)
            self.release = release_hash
            self.release_id = set_global_release(global_release_hash)
          end
          self.updated_at = save_time
        end
      end
      validate(stripped_data_hash) # return error/warnings from validation
    end

<<<<<<< 67c44807463a4811b6c8826f9b398dddd2c62b92
    def set_data_hash_attribute(key, value)
      key_hash = metadata.dig('validation', 'properties', key)

      unless key_hash.nil?
        ActiveRecord::Base.transaction do
          storage_cases_set(key, value, key_hash)
        end
      end
    end

    def to_history (save_time)
=======
    def to_history(save_time)
>>>>>>> history wired to get_data_hash, set_data_hash
      origin_table = self.class.to_s.split("::")[1].tableize
      data_set_history = (self.class.to_s + "::History").safe_constantize.new

      ActiveRecord::Base.transaction do

        # cc self to history
        data_set_history.send(origin_table.singularize.foreign_key+"=", self.id)
        self.attributes.except("id").each do |key,value|
          data_set_history.send("#{key}=", value)
        end

        lower_bound = self.updated_at
        if lower_bound > save_time
          lower_bound = save_time
        end
        data_set_history.history_valid = (lower_bound ... save_time)
        data_set_history.save

        # cc classification_relation to history
        self.send("classification_"+origin_table).all.each do |item|
          classification_history = ("DataCycleCore::Classification" + origin_table.classify + "::History").safe_constantize.new
          classification_history.send(origin_table.singularize + "_history_id=", data_set_history.id)
          item.attributes.except("id", origin_table.singularize.foreign_key).each do |key,value|
            classification_history.send("#{key}=", value)
          end
          classification_history.classification_id = item.classification_id
          #classification_history.history_valid = (item.updated_at ... save_time)
          classification_history.save
        end

        # cc embedded data from other content tables
        embedded_relations.map(&:singularize).each do |content_name|
          content_relation_table = [content_name, origin_table.singularize].sort.join('_')
          self.send(content_name.pluralize).each do |content_item|
            new_content_history = content_item.to_history(save_time)
            data_set_history.send(content_relation_table + "_histories").create({
                (origin_table.singularize + "_history_id") => data_set_history.id,
                (content_name + "_history_id") => new_content_history.id,
                "history_valid" => (content_item.updated_at ... save_time)
              })
          end
        end

        # cc embedded data from same content table
        data_refs = embedded_self_property_names.map{ |name|
          name + '_hasPart'
        }.each { |key|
          data_set_history.metadata[key] = []
          unless self.metadata[key].blank?
            self.metadata[key].each do |content_id|
              content_history = self.class.find(content_id).to_history(save_time)
              data_set_history.metadata[key].push(content_history.id)
            end
          end
        }
        data_set_history.save
      end

      data_set_history
    end

    def delete_childs(delete_relation)
      template_hash = metadata['validation']
      # check for subtrees
      template_hash['properties'].each do |key,value|
        # cleanup embeddedObjects
        if value['type'] == 'object' && value.has_key?('name') && value.has_key?('description')
          #puts "Object: #{value['name']}|#{value['description']}|#{value['delete']}"
          delete = false
          delete = value['delete'] unless value['delete'].blank?
          if value['storage_location'] == self.class.table_name
            #puts "delete same table"
            field_has_part = "#{key}_hasPart"
            delete_item_keys = []
            delete_item_keys = self.metadata[field_has_part] if !self.metadata.blank? && self.metadata.has_key?(field_has_part)
            delete_item_keys.each do |key|
              item = ("DataCycleCore::" + value['storage_location'].classify).constantize.find_by(id: key)
              item.delete_childs(delete)
              item.destroy if delete
            end
          else
            #puts "delete relation table"
            present_relations = self.method(value['storage_location']).call.ids
            self.method(value['storage_location']).call.each do |item|
              item.delete_childs(delete)
              item.destroy if delete
            end
            relation = get_relation_name(value['storage_location'])
            relations = ("DataCycleCore::" + relation.classify).constantize.
              where(self.class.table_name.singularize.foreign_key.to_sym => self.id, value['storage_location'].singularize.foreign_key.to_sym => present_relations)
            relations.destroy_all unless relations.blank?
          end
        end
        # cleanup classification_relation (only if present item can be deleted)
        if delete_relation
          if value['storage_location'] == 'classification_relation'
            found_ids = get_relation_ids(value['storage_type'], value['type_name'])
            if found_ids.size > 0
              class_string = "DataCycleCore::" + value['storage_type'].classify
              class_id = self.class.to_s.demodulize.foreign_key
              class_string.constantize.
                where(
                  class_id => self.id,
                  classification_id: found_ids
                ).destroy_all
            end
          end
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

    private

    def get_relation_ids(storage_type, tree_label)
      class_string = "DataCycleCore::" + storage_type.classify
      class_id = self.class.to_s.demodulize.foreign_key
      class_string.constantize.
        where(class_id => id).
        joins(classification: [classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]]]).
        where("classification_tree_labels.name = ?", tree_label).
        pluck(:classification_id)
    end

    def set_relation_ids(storage_type, ids, tree_label, default_value)
      class_string = "DataCycleCore::" + storage_type.classify
      class_id = self.class.to_s.demodulize.foreign_key

      #puts "#{storage_type} | #{ids} | #{tree_label} | #{default_value}"
      if is_blank?(ids)
        begin
          if !default_value.blank? && ids.nil? && get_relation_ids(storage_type, tree_label).count == 0
            classification_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
                .where("classification_tree_labels.name = ?", tree_label)
                .where("classification_aliases.name = ?", default_value).first!.id
            class_string.constantize.
              find_or_create_by(
                class_id => self.id,
                classification_id: classification_id
              )
            ids = [classification_id]
          elsif !default_value.blank? && ids.nil?
            ids = get_relation_ids(storage_type, tree_label)
          end
        rescue ActiveRecord::RecordNotFound => e
          logger.error "Missing default value '#{default_value}' for classification tree '#{tree_label}'"
          raise e
        end
      else
        # insert missing ids
        ids.each do |classification_id|
          class_string.constantize.
            find_or_create_by(
              class_id => self.id,
              classification_id: classification_id
            )
        end
      end

      ids = [] if ids.blank? && default_value.blank?
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

    def get_template_data_hash(properties, origin = [])
      data_hash = {}
      properties.each do |key,value|
        data_hash[key] = storage_cases_get(key,properties[key], origin)
      end
      data_hash
    end

    def set_template_data_hash(data_hash, properties, save_time)
      properties.each do |key,value|
        #puts " key ----> #{key} | value: #{value} || #{data_hash[key]} | #{data_hash}"
        storage_cases_set(key, data_hash[key], value, save_time)
      end
    end

    def storage_cases_get(key, properties, origin)
      case properties["storage_location"]
      when "column"
        self.method(key).call
      when "content"
        get_from_jsonb(key, properties, origin, 'content')
      when "metadata"
        get_from_jsonb(key, properties, origin, 'metadata')
      when "properties"
        get_from_jsonb(key, properties, origin, 'properties')
      when "classification_relation"
        get_relation_ids(properties["storage_type"], properties["type_name"])
      when "key"
        self.id
      else
        get_linked_data_type(key, properties['storage_location'], properties['name'], properties['description'])
      end
    end

    def storage_cases_set(key, value, properties, save_time)
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
        set_relation_ids(properties['storage_type'], value, properties['type_name'], properties['default_value'])
      else
        unless properties['storage_location'] == 'key'  # do nothing with key
          if properties.has_key?('name') && properties.has_key?('description')
            delete = false
            delete = true if properties.has_key?('delete') && properties['delete'] == true
            #puts "set_linked_data_type(#{key}, #{value}, #{properties['storage_location']}, #{properties['name']}, #{properties['description']}, #{delete})"
            set_linked_data_type(key, value, properties['storage_location'], properties['name'], properties['description'], delete, save_time)
          else
            puts "wrong data_type #{key} | #{value}"
          end
        end
      end
    end

    def get_from_jsonb(key, properties, origin, field_name)
      #puts "#{key} | #{origin} | #{field_name} || #{properties}" #if properties['type'] == 'object'
      if properties['type'] == 'object'
        # object found ==> recursively retrieve data
        new_origin = origin + [key]
        result = get_template_data_hash(properties['properties'], new_origin).compact
      else
        # data element found ==> get data within jsonb-tree-structure
        result = self.method(field_name).call
        origin = origin + [key]
        origin.each do |item|
          result = result[item] unless result.nil?
          return nil if result.nil?
        end
      end
      result.blank? ? nil : result  # conserve old behavior (empty objects return as nil)
    end

    def save_to_jsonb(key, data, properties, location)
      # parse tree in json, to only set data specified in the data definitions
      if properties['type'] == 'object' && data.is_a?(::Hash) # object with potentially relevant data
        #puts "#{key}|#{data}|#{new_origin}|#{location}"
        data = set_data_tree_hash(data, properties['properties'], location)
        #puts "#{data}"
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

    def get_linked_data_type(field_name, table, name, description)
      return_data = []

      # check if external relation or relation to itself
      if table == self.class.table_name
        field_has_part = "#{field_name}_hasPart"
        if !self.metadata.blank? && self.metadata.has_key?(field_has_part)
          self.metadata[field_has_part].each do |item|
            data_set = self.class.find_by(id: item)
            return_data.push(data_set.get_data_hash)
          end
        end
      else
        self.method(table).call.each do |item|
          return_data.push(item.get_data_hash)
        end
      end
      return_data.compact
    end

    def set_linked_data_type(field_name, data, table, name, description, delete, save_time)
      # check if it is a relation to itself or external via relation_table
      if table == self.class.table_name
        #puts "set_linked_via_tree"
        set_linked_via_tree(field_name, data, table, name, description, delete, save_time)
      else
        #puts "set_linked_via_relation"
        set_linked_via_relation(data, table, name, description, delete, save_time)
      end
    end

    def set_linked_via_relation(data, table, name, description, delete, save_time)
      relation = get_relation_name(table)
      updated_item_keys = []

      unless is_blank?(data)
        # update/insert linked_data
        data.each do |item|
          if item.has_key?('id') && !item['id'].blank? && item.keys.count == 1
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
            update_item.set_data_hash(item, save_time)
            update_item.save
            updated_item_keys.push(update_item.id)
          else
            # insert

            # get validation template
            template = ("DataCycleCore::"+table.classify).constantize
              .with_translations('de')
              .find_by("template = true AND metadata->'validation'->>'name' = ? AND metadata->'validation'->>'description' = ?", name,  description )

            insert_item = ("DataCycleCore::"+table.classify).constantize.new
            insert_item.metadata = { 'validation' => template.metadata['validation'] }
            insert_item.save
            insert_item.set_data_hash(item, save_time)
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

      available_update_item_keys = self.method(table).call.ids
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
            # ("DataCycleCore::"+relation.classify).constantize.
            #   find_by(self.class.table_name.singularize.foreign_key.to_sym => self.id, table.singularize.foreign_key.to_sym => key).
            #   destroy   # now automatically done by Rails-relation
          else
            # only destroy particular translation !
            item.translation.destroy
          end
        end
      else
        # only destroy relations (independend of how many translations in self/embeddedObject exist)
        potentially_delete.each do |key|
          ("DataCycleCore::"+relation.classify).constantize.
            find_by(self.class.table_name.singularize.foreign_key.to_sym => self.id, table.singularize.foreign_key.to_sym => key).
            destroy
        end
      end
      self.method(table).call.reload # MO: force reload of the relation, otherwise cached data can obsure the next get_data_hash
    end

    def set_linked_via_tree(field_name, data, table, name, description, delete, save_time)
      # get validation template
      template = ("DataCycleCore::"+table.classify).constantize
        .with_translations('de')
        .find_by("template = true AND metadata->'validation'->>'name' = ? AND metadata->'validation'->>'description' = ?", name,  description )

      updated_item_keys = []
      field_has_part = "#{field_name}_hasPart"

      unless is_blank?(data)
        # update/insert linked_data
        data.each do |item|
          if item.has_key?('id') && !item['id'].blank? && item.keys.count == 1
            # id is the only item --> no update of data_set
            item_id = item['id']
          elsif item.has_key?('id') && !item['id'].blank?
            # update
            update_item = ("DataCycleCore::"+table.classify).constantize.find_by(id: item['id'])
            update_item.set_data_hash(item, save_time)
            update_item.save
            item_id = item['id']
          else
            # insert
            insert_item = ("DataCycleCore::"+table.classify).constantize.new
            insert_item.metadata = { 'validation' => template.metadata['validation'] }
            insert_item.save
            insert_item.set_data_hash(item, save_time)
            insert_item.isPartOf = self.id
            insert_item.save
            item_id = insert_item.id
          end
          updated_item_keys.push(item_id)
          # update relation
          if self.metadata.blank?
            self.metadata = { field_has_part => [ item_id ] }
            self.save
          elsif self.metadata[field_has_part].blank?
            self.metadata[field_has_part] = [ item_id ]
            self.save
          elsif !self.metadata[field_has_part].include?(item_id)
            self.metadata[field_has_part].push(item_id)
            self.save
          end
        end
      end

      available_update_item_keys = []
      available_update_item_keys = self.metadata[field_has_part] if !self.metadata.blank? && self.metadata.has_key?(field_has_part)
      potentially_delete = available_update_item_keys - updated_item_keys

      if delete
        # full access to embeddedObjects
        potentially_delete.each do |key|
          item = ("DataCycleCore::"+table.classify).constantize.find_by(id: key)
          translations = item.translated_locales
          if (translations-[ I18n.locale ]).size < 1
            # find relation and destroy it
            item.delete_childs(delete)
            item.destroy
            self.metadata[field_has_part] -= [ key ] # remove reference
          else
            # only destroy particular translation !
            item.translation.destroy
          end
        end
      else
        # replace hasPart with given updated_item_keys
        self.metadata[field_has_part] = updated_item_keys
      end
    end

    # make a rails conform name for a relation table
    def get_relation_name(table)
      tables = [ table , self.class.table_name ].sort
      tables[0].singularize+"_"+tables[1]
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
