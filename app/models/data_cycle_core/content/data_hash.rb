# frozen_string_literal: true

module DataCycleCore
  module Content
    class DataHash < DataCycleCore::Content::Content
      self.abstract_class = true
      define_model_callbacks :save_data_hash, only: :before
      define_model_callbacks :saved_data_hash, only: [:before, :after]
      define_model_callbacks :created_data_hash, only: :after
      define_model_callbacks :destroyed_data_hash, only: :after

      DataCycleCore.features.select { |_, v| !v.dig(:only_config) == true }.each_key do |key|
        feature = ('DataCycleCore::Feature::' + key.to_s.classify).constantize
        prepend feature.data_hash_module if feature.enabled? && feature.data_hash_module
      end

      include CreateHistory
      include UpdateSearch

      before_save :set_internal_data
      before_save_data_hash :inherit_source_attributes, if: -> { @new_content && @source.present? }
      before_save_data_hash :add_default_values, if: -> { properties_with_default_values.present? }
      before_save_data_hash :set_computed_values, if: -> { computed_property_names.present? }
      after_saved_data_hash :execute_update_webhooks, if: -> { !embedded? }
      after_saved_data_hash :notify_subscribers, if: -> { @current_user.present? }
      after_saved_data_hash :add_related_cache_invalidation_job, if: -> { @invalidate_related_cache && !embedded? && has_cached_related_contents? }
      after_created_data_hash :execute_create_webhooks, if: -> { !embedded? }
      after_destroyed_data_hash :execute_delete_webhooks, if: -> { !embedded? }

      def set_data_hash(
        data_hash:,
        current_user: nil,
        save_time: Time.zone.now,
        prevent_history: false,
        update_search_all: true,
        partial_update: false,
        source: nil,
        new_content: false,
        force_update: false,
        version_name: nil,
        invalidate_related_cache: true,
        check_for_duplicates: false
      )
        return {} if data_hash.blank? && !force_update
        @data_hash = data_hash.dup.with_indifferent_access
        @current_user = current_user
        @save_time = save_time
        @prevent_history = prevent_history
        @source = source
        @new_content = new_content
        @partial_update = partial_update
        @invalidate_related_cache = invalidate_related_cache
        @check_for_duplicates = check_for_duplicates
        run_callbacks :save_data_hash

        partial_schema_hash = nil
        if @partial_update
          partial_schema_hash = schema.dup
          partial_schema_hash['properties'] = property_definitions&.slice(*@data_hash.keys)
        end

        valid_hash = validate(@data_hash.dup, partial_schema_hash || schema)

        if validate?(valid_hash)
          if diff?(@data_hash.dup, partial_schema_hash) || force_update
            ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
              to_history(save_time: @save_time) unless id.nil? || prevent_history

              set_template_data_hash(@data_hash, partial_schema_hash&.dig('properties') || property_definitions)

              self.updated_at = @save_time
              self.updated_by = @current_user&.id
              self.version_name = DataCycleCore::Feature::NamedVersion.enabled? ? version_name.presence : nil

              if id.nil?
                self.created_at = @save_time
                self.created_by = @current_user&.id
              end
              save(touch: false)
              search_languages(update_search_all) unless id.nil? || embedded?
            end

            reload
            run_callbacks(:saved_data_hash)
            run_callbacks(:created_data_hash) if @new_content
          else
            valid_hash[:warning] = I18n.t('controllers.warning.no_changes', locale: DataCycleCore.ui_language)
          end
        end
        valid_hash
      end

      def set_computed_values
        computed_property_names.each do |computed_property|
          @data_hash[computed_property] = DataCycleCore::Utility::Compute::Base.computed_values(computed_property, properties_for(computed_property), @data_hash, self)
        end
      end

      def add_default_values(force: false)
        if @new_content || force
          props = properties_with_default_values.select { |k, _| attribute_blank?(k) }
        elsif translated_locales.presence&.exclude?(I18n.locale)
          props = properties_with_default_values.select { |k, _| attribute_blank?(k) }.slice(*translatable_property_names)
        else
          props = properties_with_default_values.select { |k, _| attribute_blank?(k) }.slice(*@data_hash.keys)
        end

        return @data_hash if props.blank?

        props.each do |property_name, property_definition|
          @data_hash[property_name] = DataCycleCore::Utility::DefaultValue::Base.default_values(property_name, property_definition, @data_hash, self, @current_user)
        end

        @data_hash
      end

      def inherit_source_attributes
        I18n.with_locale(@source.first_available_locale) do
          source_data_hash = @source.get_data_hash
          @data_hash = source_data_hash.slice(*DataCycleCore.inheritable_attributes).merge(@data_hash)
        end
      end

      def execute_update_webhooks
        Webhook::Update.execute_all(self)
      end

      def execute_create_webhooks
        Webhook::Create.execute_all(self)
      end

      def execute_delete_webhooks
        Webhook::Delete.execute_all(self)
      end

      def validate(data, schema_hash = nil, strict = false, add_defaults = false, current_user = nil)
        if add_defaults && properties_with_default_values.present?
          @data_hash = data
          @current_user = current_user
          data = add_default_values.dup
        end

        validator = DataCycleCore::MasterData::ValidateData.new
        validator.validate(data, schema_hash || schema, strict)
      end

      def validate?(validation_hash)
        validation_hash&.dig(:error).blank?
      end

      def set_internal_data
        self.content_type = schema&.dig('content_type')
        self.boost = schema&.dig('boost') || 1.0
        validity_hash = metadata.nil? ? nil : metadata['validity_period']
        self.validity_range = get_validity_range(validity_hash)
      end

      def add_related_cache_invalidation_job
        Delayed::Job.enqueue DataCycleCore::Jobs::CacheInvalidationJob.new(self.class.name, id, :invalidate_related_cache) unless Delayed::Job.exists?(queue: 'cache_invalidation', delayed_reference_type: "#{self.class.name.underscore}_invalidate_related_cache", delayed_reference_id: id, locked_at: nil)
      end

      def invalidate_self_and_update_search
        search_languages(true)
        invalidate_self
      end

      def invalidate_self
        Rails.cache.delete_matched("*#{id}*")
        invalidate_related_cache
      end

      def invalidate_related_cache
        cached_related_contents.ids.each do |item_id|
          Rails.cache.delete_matched("*#{item_id}*")
        end
      end

      private

      def attribute_blank?(key, _defininition = nil)
        return true if key.blank?

        @data_hash[key].blank? &&
          !@data_hash[key].is_a?(FalseClass) &&
          try(key).blank? &&
          !try(key).is_a?(FalseClass)
      end

      def notify_subscribers
        subscriptions.except_user(@current_user).to_notify(version_name.present? && DataCycleCore::Feature::NamedVersion.enabled? ? ['always', 'named_version'] : ['always']).presence&.each do |subscription|
          DataCycleCore::SubscriptionMailer.notify(subscription.user, [self]).deliver_later
        end
      end

      def set_template_data_hash(data_hash, properties)
        properties.each do |key, value|
          storage_cases_set(key, data_hash[key], value)
        end
      end

      def storage_cases_set(key, value, properties)
        # puts "#{key}, #{value}, #{properties.dig('type')}"
        case properties['type']
        when 'linked'
          set_linked(key, value, properties)
        when 'embedded'
          set_embedded(key, value, properties['template_name'], properties['translated'])
        when 'string', 'number', 'datetime', 'date', 'boolean', 'geographic', 'object'
          save_values(key, value, properties)
        when 'classification'
          set_classification_relation_ids(value, key, properties['tree_label'], properties['default_value'], properties['not_translated'], properties['universal'])
        when 'asset'
          set_asset_id(value, key, properties['asset_type'])
        when 'schedule'
          set_schedule(value, key)
        when 'computed'
          save_values(key, value, properties)
        when 'key'
          true # do nothing
        end
      end

      def save_values(key, value, properties)
        case properties['storage_location']
        when 'column'
          save_to_column(key, value, properties)
        when 'value'
          save_to_jsonb(key, value, properties, 'metadata')
        when 'translated_value'
          save_to_jsonb(key, value, properties, 'content')
        end
      end

      def save_to_column(key, value, properties)
        send("#{key}=", normalize_value(value, properties))
      end

      def normalize_value(value, properties)
        norm_value = value
        # if properties.key?('default_value') && value.blank?
        #   if properties['default_value'].is_a?(String) && /{{.*}}/.match?(properties['default_value']) # eval code enclosed in double curly braces: {{ ... }}
        #     norm_value = eval(properties['default_value'][2..-3]) # rubocop:disable Security/Eval
        #   else
        #     norm_value = properties['default_value']
        #   end
        # end
        return DataCycleCore::MasterData::DataConverter.string_to_string(norm_value) if properties['type'] == 'string'
        norm_value
      end

      def save_to_jsonb(key, data, properties, location)
        save_data = data.deep_dup
        save_data = set_data_tree_hash(save_data, properties['properties'], location) if properties['type'] == 'object'
        save_data = convert_to_string(properties['type'], normalize_value(save_data, properties)) if PLAIN_PROPERTY_TYPES.include?(properties['type'])

        if send(location.to_s).blank? # set to json field (could be empty)
          send("#{location}=", { key => save_data })
        else
          send(location.to_s).method('[]=').call(key, save_data)
        end
      end

      def set_data_tree_hash(data, data_definitions, location)
        data_hash = {}
        data_definitions.each_key do |key|
          if data_definitions[key]['type'] == 'object'
            data_hash[key] = set_data_tree_hash(data&.dig(key), data_definitions[key]['properties'], location)
          elsif (data_definitions[key]['storage_location'] == 'value' && location == 'metadata') || (data_definitions[key]['storage_location'] == 'translated_value' && location == 'content')
            data_hash[key] = convert_to_string(data_definitions[key]['type'], normalize_value(data&.dig(key), data_definitions[key]))
          elsif data_definitions[key]['storage_location'] == 'column'
            save_to_column(key, data&.dig(key), data_definitions[key])
          end
        end
        data_hash
      end

      def set_linked(field_name, input_data, properties)
        return if properties['link_direction'] == 'inverse' # inverse direction is read_only
        relation_b = properties['inverse_of']

        item_ids_before_update = send(field_name).ids
        item_ids_after_update = parse_linked_ids(input_data)

        item_ids_after_update.each_index do |index|
          update_relation = DataCycleCore::ContentContent.find_or_create_by({
            content_a_id: id,
            relation_a: field_name,
            content_b_id: item_ids_after_update[index]
          })
          update_relation.order_a = index
          update_relation.relation_b = relation_b
          update_relation.save!
        end

        item_ids_to_delete = item_ids_before_update - item_ids_after_update
        return if item_ids_to_delete.size.zero?

        DataCycleCore::ContentContent
          .where({
            content_a_id: id,
            relation_a: field_name,
            content_b_id: item_ids_to_delete
          })
          .destroy_all
      end

      def parse_linked_ids(a)
        return [] if is_blank?(a)
        data = a.is_a?(::String) ? [a] : a
        data = a&.ids if data.is_a?(ActiveRecord::Relation)
        raise ArgumentError, 'expected a uuid or list of uuids' unless data.is_a?(::Array)
        data
      end

      def set_embedded(field_name, input_data, name, translated)
        updated_item_keys = []
        available_update_item_keys = load_embedded_objects(field_name, nil, !translated).ids.uniq
        data = input_data || []

        data.each_index do |index|
          item = data[index]
          if item.key?('id') && item['id'].present?
            upsert_content(name, item) if item.keys.size > 1

            if available_update_item_keys[index] != item['id']
              upsert_relation = DataCycleCore::ContentContent.find_or_create_by!({
                content_a_id: id,
                relation_a: field_name,
                content_b_id: item['id']
              })
              upsert_relation.order_a = index
              upsert_relation.save
            end

            updated_item_keys << item['id']
          else
            insert_item = upsert_content(name, item)
            DataCycleCore::ContentContent.create!({
              content_a_id: id,
              relation_a: field_name,
              order_a: index,
              content_b_id: insert_item.id
            })
            updated_item_keys << insert_item.id
          end
        end

        potentially_delete = available_update_item_keys - updated_item_keys
        potentially_delete.each do |key|
          # fully destroy all remaining embedded!
          item = DataCycleCore::Thing.find_by(id: key)
          item.destroy_children(current_user: @current_user, save_time: @save_time, destroy_locale: false)
          item.destroy
        end
      end

      def upsert_content(name, item)
        template = DataCycleCore::Thing.find_by(template: true, template_name: name)
        if item['id'].present?
          upsert_item = DataCycleCore::Thing.find_or_initialize_by(id: item['id'])
        else
          upsert_item = DataCycleCore::Thing.new
        end
        upsert_item.schema = template.schema
        upsert_item.template_name = template.template_name
        # TODO: check if external_source_id is required
        upsert_item.external_source_id = external_source_id
        created = upsert_item.new_record?
        upsert_item.save
        upsert_item.set_data_hash(data_hash: item, current_user: @current_user, save_time: @save_time, prevent_history: true, new_content: created)
        upsert_item
      end

      def set_classification_relation_ids(ids, relation_name, _tree_label, default_value, not_translated, universal)
        return if not_translated && I18n.available_locales.first != I18n.locale && default_value.blank?
        present_relation_ids = send(relation_name).pluck(:classification_id) || []
        ids ||= []
        if is_blank?(ids) && !universal
          # if default_value.present?
          #   classification_id = load_default_classification(tree_label, default_value)
          #   ids = [classification_id] # the convention is: don't delete the default_value
          #   if present_relation_ids.count.zero?
          #     DataCycleCore::ClassificationContent.find_or_create_by!(
          #       'content_data_id' => id,
          #       classification_id: classification_id,
          #       relation: relation_name
          #     )
          #   end
          # end
        else
          ids.each do |classification_id_value|
            next if present_relation_ids.include?(classification_id_value)
            DataCycleCore::ClassificationContent.find_or_create_by!(
              'content_data_id' => id,
              classification_id: classification_id_value,
              relation: relation_name
            )
          end
        end

        to_delete = present_relation_ids - ids
        return if to_delete.empty?
        DataCycleCore::ClassificationContent
          .with_content(id)
          .with_classification_ids(to_delete)
          .with_relation(relation_name)
          .destroy_all
      end

      def set_asset_id(asset_id, relation_name, asset_type)
        asset_id = asset_id.first.id if asset_id.is_a?(ActiveRecord::Relation) || asset_id.is_a?(::Array)
        asset_id = asset_id.id if asset_id.is_a?(DataCycleCore::Asset)

        if id.present? && asset_id.present?
          DataCycleCore::AssetContent.find_or_create_by(
            'content_data_id' => id,
            'content_data_type' => self.class.to_s,
            asset_id: asset_id,
            asset_type: asset_type,
            relation: relation_name
          )
        end

        # delete old asset if necessary
        old_id = load_asset_relation(relation_name)&.id
        return if old_id == asset_id
        DataCycleCore::AssetContent
          .with_content(id, self.class.to_s)
          .with_assets(old_id, asset_type)
          .with_relation(relation_name)
          .destroy_all
      end

      def set_schedule(input_data, relation_name)
        updated_item_keys = []
        available_items = load_schedule(relation_name).ids
        data = input_data || []

        data.each do |item|
          schedule =
            if item['id'].present?
              DataCycleCore::Schedule.find_by(id: item['id'], thing_id: id, relation: relation_name)
            else
              DataCycleCore::Schedule.new(thing_id: id, relation: relation_name)
            end
          schedule.from_hash(item.with_indifferent_access)
          schedule.save!
          updated_item_keys << schedule.id
        end

        delete = available_items - updated_item_keys
        DataCycleCore::Schedule.where(id: delete).destroy_all
      end
    end
  end
end
