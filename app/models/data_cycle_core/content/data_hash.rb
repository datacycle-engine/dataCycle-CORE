# frozen_string_literal: true

module DataCycleCore
  module Content
    class DataHash < DataCycleCore::Content::Content
      self.abstract_class = true
      attr_accessor :finalize
      define_model_callbacks :save_data_hash, only: :before
      define_model_callbacks :saved_data_hash, only: :after

      DataCycleCore.features.each_key do |key|
        module_name = ('DataCycleCore::Feature::DataHash::' + key.to_s.classify).constantize
        include module_name if ('DataCycleCore::Feature::' + key.to_s.classify).constantize.enabled?
      end
      include CreateHistory
      include UpdateSearch

      before_save_data_hash :set_last_updated_by, if: -> { schema&.dig('properties', 'last_updated_by').present? }
      before_save_data_hash :set_computed_values, if: -> { computed_property_names.present? }
      before_save_data_hash :inherit_source_attributes, if: -> { @new_content && @source.present? }
      after_saved_data_hash :execute_webhooks, if: -> { self.class.name == 'DataCycleCore::CreativeWork' }
      after_saved_data_hash :notify_subscribers, if: -> { @current_user.present? }

      def set_data_hash(data_hash:, current_user: nil, save_time: Time.zone.now, prevent_history: false, update_search_all: true, partial_update: false, source: nil, new_content: false)
        return {} if data_hash.blank?
        @data_hash = data_hash
        @current_user = current_user
        @save_time = save_time
        @prevent_history = prevent_history
        @source = source
        @new_content = new_content
        run_callbacks :save_data_hash

        schema_hash = { 'properties' => schema['properties']&.slice(*@data_hash.keys) } if partial_update

        valid_hash = validate(@data_hash, schema_hash)

        if validate?(valid_hash) && diff?(@data_hash)
          ActiveRecord::Base.transaction do
            to_history(save_time: @save_time) unless id.nil? || prevent_history

            set_template_data_hash(@data_hash, partial_update ? property_definitions.slice(*@data_hash.keys) : property_definitions)

            self.updated_at = @save_time
            self.created_at = @save_time if id.nil?
            save(touch: false)

            search_languages(update_search_all)
          end
          run_callbacks :saved_data_hash unless prevent_history
        end
        valid_hash
      end

      def set_last_updated_by
        @data_hash = @data_hash.merge({ 'last_updated_by' => [@current_user.presence&.id || (@prevent_history ? try(:last_updated_by).presence&.first&.id : nil)] })
      end

      def set_computed_values
        computed_property_names.each do |computed_property|
          @data_hash[computed_property] = DataCycleCore::Utility::Compute::Base.computed_values(properties_for(computed_property), @data_hash)
        end
      end

      def inherit_source_attributes
        I18n.with_locale(@source.first_available_locale) do
          source_data_hash = @source.get_data_hash
          @data_hash = source_data_hash.slice(*DataCycleCore.inheritable_attributes).merge(@data_hash)
        end
      end

      def execute_webhooks
        Webhook::Update.execute_all(@content)
      end

      def get_inherit_datahash(parent)
        data_hash = get_data_hash

        I18n.with_locale(parent.first_available_locale) do
          parent_data_hash = parent.get_data_hash

          DataCycleCore.inheritable_attributes.each do |attribute_key|
            parent_data = parent_data_hash[attribute_key]
            data_hash[attribute_key] = parent_data if parent_data.present?
          end

          data_hash[DataCycleCore::Feature::LifeCycle.attribute_keys.first] = parent_data_hash[DataCycleCore::Feature::LifeCycle.attribute_keys.first] if DataCycleCore::Feature::LifeCycle.enabled?
        end

        data_hash.compact!
      end

      def validate(data, schema_hash = nil)
        validator = DataCycleCore::MasterData::ValidateData.new
        validator.validate(data, schema_hash || schema)
      end

      def validate?(validation_hash)
        validation_hash&.dig(:error).blank?
      end

      private

      def notify_subscribers
        return if @current_user.blank?
        subscriptions.except_user(@current_user).to_notify.presence&.each do |subscription|
          DataCycleCore::SubscriptionMailer.notify(subscription.user, [self]).deliver_later
        end
      end

      def set_template_data_hash(data_hash, properties)
        properties.each do |key, value|
          storage_cases_set(key, data_hash[key], value)
        end
      end

      def storage_cases_set(key, value, properties)
        case properties['type']
        when 'linked'
          set_linked(key, value, properties['linked_table'])
        when 'embedded'
          set_embedded(key, value, properties['linked_table'], properties['template_name'])
        when 'string', 'number', 'datetime', 'boolean', 'geographic', 'object'
          save_values(key, value, properties)
        when 'classification'
          set_classification_relation_ids(value, key, properties['tree_label'], properties['default_value'])
        when 'asset'
          set_asset_id(value, key, properties['asset_type'])
        when 'computed'
          save_values(key, value, properties)
        when 'key'
          true # do nothing
        end
      end

      def save_values(key, value, properties)
        case properties['storage_location']
        when 'column'
          send("#{key}=", normalize_string(value, properties))
        when 'value'
          save_to_jsonb(key, value, properties, 'metadata')
        when 'translated_value'
          save_to_jsonb(key, value, properties, 'content')
        end
      end

      def normalize_string(value, properties)
        return DataCycleCore::MasterData::DataConverter.string_to_string(value) if properties['type'] == 'string'
        value
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
            send("#{key}=", normalize_string(data[key], data_definitions[key]))
          end
        end
        data_hash
      end

      def set_linked(field_name, input_data, table)
        item_ids_before_update = send(field_name).ids
        selector = table < self.class.table_name
        item_ids_after_update = parse_linked_ids(input_data)

        item_ids_after_update.each_index do |index|
          next if item_ids_before_update[index] == item_ids_after_update[index]

          upsert_relation = DataCycleCore::ContentContent.find_or_create_by(
            get_relation_data_hash(field_name, table, item_ids_after_update[index])
          )
          upsert_relation.send(selector ? 'order_b=' : 'order_a=', index)
          upsert_relation.save
        end

        item_ids_to_delete = item_ids_before_update - item_ids_after_update
        return if item_ids_to_delete.size.zero?
        # destroy relations
        DataCycleCore::ContentContent
          .where(get_relation_data_hash(field_name, table, item_ids_to_delete))
          .destroy_all
      end

      def parse_linked_ids(a)
        return [] if a.blank?
        data = a.is_a?(::String) ? [a] : a
        data = a&.ids if data.is_a?(ActiveRecord::Relation)
        raise ArgumentError, 'expected a uuid or list of uuids' unless data.is_a?(::Array)
        data
      end

      def set_embedded(field_name, input_data, table, name)
        updated_item_keys = []
        available_update_item_keys = send(field_name).ids
        selector = table < self.class.table_name
        data = parse_embedded_content(input_data) || []

        data.each_index do |index|
          item = data[index]
          if item.key?('id') && item['id'].present?
            upsert_content(table, name, item) if item.keys.size > 1

            if available_update_item_keys[index] != item['id']
              upsert_relation = DataCycleCore::ContentContent.find_or_create_by(
                get_relation_data_hash(field_name, table, item['id'])
              )
              upsert_relation.send(selector ? 'order_b=' : 'order_a=', index)
              upsert_relation.save
            end

            updated_item_keys << item['id']
          else
            insert_item = upsert_content(table, name, item)

            order_hash = selector ? { order_a: nil, order_b: index } : { order_a: index, order_b: nil }
            DataCycleCore::ContentContent.create!(
              get_relation_data_hash(field_name, table, insert_item.id).merge(order_hash)
            )

            updated_item_keys << insert_item.id
          end
        end

        potentially_delete = available_update_item_keys - updated_item_keys
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
      end

      def parse_embedded_content(a)
        if a.is_a?(ActiveRecord::Relation)
          a.ids.map { |item| { 'id' => item } }
        elsif a.is_a?(::String)
          { 'id' => a }
        elsif a.is_a?(::Array) && a.present? && a.first.is_a?(::String)
          a.map { |item| { 'id' => item } }
        else
          a
        end
      end

      def upsert_content(table, name, item)
        template = load_template(table, name)
        if item['id'].present?
          upsert_item = ('DataCycleCore::' + table.classify).constantize.find_or_create_by(id: item['id'])
        else
          upsert_item = ('DataCycleCore::' + table.classify).constantize.new
        end
        upsert_item.schema = template.schema
        upsert_item.template_name = template.template_name
        upsert_item.save
        upsert_item.set_data_hash(data_hash: item, current_user: @current_user, save_time: @save_time, prevent_history: true)
        upsert_item
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
