# frozen_string_literal: true

module DataCycleCore
  module Content
    class DataHash < DataCycleCore::Content::Content
      self.abstract_class = true
      include CreateHistory
      include UpdateSearch
      include Features

      define_model_callbacks :save_data_hash, only: :before
      define_model_callbacks :saved_data_hash, only: :after
      before_save_data_hash :set_last_updated_by

      def set_data_hash(data_hash:, current_user: nil, save_time: Time.zone.now, prevent_history: false, update_search_all: true)
        @data_hash = data_hash
        @current_user = current_user
        @save_time = save_time
        @prevent_history = prevent_history
        run_callbacks :save_data_hash

        valid_hash = validate(data_hash)
        if validate?(valid_hash) && diff?(@data_hash)
          ActiveRecord::Base.transaction do
            to_history(save_time: @save_time) if id.nil? == false && prevent_history == false

            set_template_data_hash(@data_hash, property_definitions)

            self.updated_at = @save_time
            self.created_at = @save_time if id.nil?
            save(touch: false)

            search_languages(update_search_all)
          end
          run_callbacks :saved_data_hash
        end
        valid_hash
      end

      def set_last_updated_by
        @data_hash = @data_hash.merge({ 'last_updated_by' => [@current_user.presence&.id || (@prevent_history ? try(:last_updated_by).presence&.first&.id : nil)] })
      end

      def validate(data)
        validator = DataCycleCore::MasterData::ValidateData.new
        validator.validate(data, schema)
      end

      def validate?(validation_hash)
        validation_hash&.dig(:error).blank?
      end

      private

      def set_template_data_hash(data_hash, properties)
        properties.each do |key, value|
          storage_cases_set(key, data_hash[key], value)
        end
      end

      def storage_cases_set(key, value, properties)
        case properties['type']
        when 'linked'
          set_linked_data_type(key, value, properties['linked_table'], properties['template_name'], false)
        when 'embedded'
          set_linked_data_type(key, value, properties['linked_table'], properties['template_name'], true)
        when 'string', 'number', 'datetime', 'boolean', 'geographic', 'object'
          save_values(key, value, properties)
        when 'classification'
          set_classification_relation_ids(value, key, properties['tree_label'], properties['default_value'])
        when 'asset'
          set_asset_id(value, key, properties['asset_type'])
        when 'key'
          true # do nothing
        else
          raise StandardError, "Template includes a wrong data_type: #{properties['type']}; data given: #{key} | #{value}"
        end
      end

      def save_values(key, value, properties)
        case properties['storage_location']
        when 'column'
          send("#{key}=", value)
        when 'value'
          save_to_jsonb(key, value, properties, 'metadata')
        when 'translated_value'
          save_to_jsonb(key, value, properties, 'content')
        end
      end

      def save_to_jsonb(key, data, properties, location)
        save_data = data.deep_dup
        save_data = set_data_tree_hash(save_data, properties['properties'], location) if properties['type'] == 'object' && data.is_a?(::Hash)
        save_data = convert_to_string(properties['type'], save_data) if PLAIN_PROPERTY_TYPES.include?(properties['type'])

        # set to json field (could be empty)
        if send(location.to_s).blank?
          send("#{location}=", { key => save_data })
        else
          send(location.to_s).method('[]=').call(key, save_data)
        end
      end

      def set_data_tree_hash(data, data_definitions, location)
        data_hash = {}
        return if data.blank?
        data_definitions.each_key do |key|
          if data_definitions[key]['type'] == 'object'
            data_hash[key] = set_data_tree_hash(data[key], data_definitions[key]['properties'], location)
          elsif (data_definitions[key]['storage_location'] == 'value' && location == 'metadata') || (data_definitions[key]['storage_location'] == 'translated_value' && location == 'content')
            data_hash[key] = convert_to_string(data_definitions[key]['type'], data[key])
          elsif data_definitions[key]['storage_location'] == 'column'
            send("#{key}=", data[key])
          end
        end
        data_hash
      end

      def set_linked_data_type(field_name, input_data, table, name, delete)
        updated_item_keys = []
        available_update_item_keys = send(field_name).ids
        selector = table < self.class.table_name
        data = parse_linked_content(input_data)

        unless is_blank?(data)
          data.each_index do |index|
            item = data[index]
            if item.key?('id') && item['id'].present?
              # update/insert relation + data
              updated_item_keys << upsert_linked_content_relation(available_update_item_keys, field_name, table, item, selector, index)
            else
              # insert new data + relation
              updated_item_keys << insert_linked_content_and_relation(field_name, table, name, item, selector, index)
            end
          end
        end

        potentially_delete = available_update_item_keys - updated_item_keys
        if delete
          # full access to embeddedObjects
          potentially_delete.each do |key|
            item = ('DataCycleCore::' + table.classify).constantize.find_by(id: key)
            translations = item.translated_locales
            if (translations - [I18n.locale]).empty?
              # destroy relationObject + additional embeddedObjects and their relations
              to_update_item = send(table).find_by(id: key)
              to_update_item.destroy_children
              to_update_item.destroy
            else
              # only destroy particular translation !
              item.translation.destroy
            end
          end
        else
          # destroy relations
          DataCycleCore::ContentContent
            .where(get_relation_data_hash(field_name, table, potentially_delete))
            .destroy_all
        end
        # send(table).reload # MO: force reload of the relation, otherwise cached data can obscure the next get_data_hash
      end

      def parse_linked_content(input_data)
        if input_data.is_a?(ActiveRecord::Relation)
          input_data.ids.map { |item| { 'id' => item } }
        elsif input_data.is_a?(::String)
          { 'id' => input_data }
        elsif input_data.is_a?(::Array) && input_data.present? && input_data.first.is_a?(::String)
          input_data.map { |item| { 'id' => item } } # for embeddedLinkArray transform data
        else
          input_data
        end
      end

      def upsert_linked_content_relation(available_update_item_keys, field_name, table, item, selector, index)
        if available_update_item_keys[index] != item['id']
          # update relation
          upsert_relation = DataCycleCore::ContentContent.find_or_create_by(
            get_relation_data_hash(field_name, table, item['id'])
          )
          upsert_relation.send(selector ? 'order_b='.to_sym : 'order_a='.to_sym, index)
          upsert_relation.save
        end
        if item.keys.count > 1
          # update actual data
          update_item = ('DataCycleCore::' + table.classify).constantize.find_by(id: item['id'])
          update_item.set_data_hash(data_hash: item, current_user: @current_user, save_time: @save_time, prevent_history: true)
          update_item.save
        end
        item['id']
      end

      def insert_linked_content_and_relation(field_name, table, name, item, selector, index)
        template = load_template(table, name)
        insert_item = ('DataCycleCore::' + table.classify).constantize.new
        insert_item.schema = template.schema
        insert_item.template_name = template.template_name
        insert_item.save
        insert_item.set_data_hash(data_hash: item.merge({ 'is_part_of' => id }), current_user: @current_user, save_time: @save_time, prevent_history: true)
        insert_item.save

        # insert_relation
        order_hash = selector ? { order_a: nil, order_b: index } : { order_a: index, order_b: nil }
        DataCycleCore::ContentContent.create!(
          get_relation_data_hash(field_name, table, insert_item.id).merge(order_hash)
        )
        insert_item.id
      end

      def get_relation_data_hash(field_name, table, item_id)
        item_data = [item_id, "DataCycleCore::#{table.classify}", '']
        self_data = [id, self.class.to_s, field_name]
        ['a', 'b'].map { |selector|
          ["content_#{selector}_id".to_sym, "content_#{selector}_type".to_sym, "relation_#{selector}".to_sym]
        }.flatten
          .zip(table < self.class.table_name ? item_data + self_data : self_data + item_data).to_h
      end

      def set_classification_relation_ids(ids, relation_name, tree_label, default_value)
        present_relation_ids = send(relation_name).pluck(:classification_id) || []
        ids ||= []
        if is_blank?(ids)
          if default_value.present?
            classification_id = load_default_classification(tree_label, default_value).id
            ids = [classification_id] # the convention is: don't delete the default_value
            if present_relation_ids.count.zero?
              DataCycleCore::ClassificationContent.create!(
                'content_data_id' => id,
                'content_data_type' => self.class.to_s,
                classification_id: classification_id,
                relation: relation_name
              )
            end
          end
        else
          ids.each do |classification_id_value|
            next if present_relation_ids.include?(classification_id_value)
            DataCycleCore::ClassificationContent.create!(
              'content_data_id' => id,
              'content_data_type' => self.class.to_s,
              classification_id: classification_id_value,
              relation: relation_name
            )
          end
        end

        to_delete = present_relation_ids - ids
        return if to_delete.empty?
        DataCycleCore::ClassificationContent
          .with_content(id, self.class.to_s)
          .with_classification_ids(to_delete)
          .with_relation(relation_name)
          .destroy_all
      end

      def set_asset_id(id, relation_name, asset_type)
        if id.present?
          DataCycleCore::AssetContent.find_or_create_by(
            'content_data_id' => self.id,
            'content_data_type' => self.class.to_s,
            asset_id: id,
            asset_type: asset_type,
            relation: relation_name
          )
        end

        # delete old id
        found_ids = load_asset_relation(relation_name).ids
        to_delete = found_ids - [id]
        return if to_delete.empty?
        DataCycleCore::AssetContent
          .with_content(self.id, self.class.to_s)
          .with_assets(to_delete, asset_type)
          .with_relation(relation_name)
          .destroy_all
      end
    end
  end
end
