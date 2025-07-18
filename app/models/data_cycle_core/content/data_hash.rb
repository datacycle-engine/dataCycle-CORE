# frozen_string_literal: true

module DataCycleCore
  module Content
    class DataHash < DataCycleCore::Content::Content
      self.abstract_class = true
      define_model_callbacks :save_data_hash, only: :before
      define_model_callbacks :saved_data_hash, only: [:before, :after]
      define_model_callbacks :created_data_hash, only: :after

      DataCycleCore.features.each_key do |key|
        feature = DataCycleCore::Feature[key]
        prepend feature.data_hash_module if feature&.enabled? && feature.data_hash_module
      end

      include CreateHistory
      include UpdateSearch

      before_save :set_internal_data
      before_destroy :add_remove_linked_from_text_job, unless: :history?

      def before_save_data_hash(options)
        # inherit attributes if source content is present
        inherit_source_attributes(**options.to_h.slice(:data_hash, :source)) if options.new_content && !options.source.nil?

        # remove empty slugs
        remove_blank_slugs!(**options.to_h.slice(:data_hash)) if options.new_content && slug_property_names.present?

        # add default value
        add_default_values(**options.to_h.slice(:data_hash, :current_user, :new_content)) if default_value_property_names.present?

        # adjust slug if it already exists in database
        transform_slugs(**options.to_h.slice(:data_hash)) if !embedded? && slug_property_names.intersect?(options.data_hash.keys)

        # add computed values
        add_computed_values(**options.to_h.slice(:data_hash, :current_user)) if computed_property_names.present? && options.update_computed
      end

      def after_save_data_hash(options)
        return if embedded?

        # trigger create webhooks if is newly created content
        execute_create_webhooks if options.new_content

        # trigger update webhooks / except if only timeseries properties changed
        execute_update_webhooks unless previous_datahash_changes.blank? ||
                                       previous_datahash_changes.keys.all? { |k| k.in?(timeseries_property_names) }

        # trigger Subscriber Mailer
        notify_subscribers(current_user: options.current_user) unless options.current_user.nil?

        # trigger cache_invalidation for related contents
        add_related_cache_invalidation_job if options.invalidate_related_cache && has_cached_related_contents?

        # trigger update of dependent computed properties
        add_update_dependent_computed_properties_job

        add_update_exif_values_job if ['Bild', 'ImageObject'].include?(template_name) && exif_property_names.present?
      end

      def before_destroy_data_hash(_options)
        # trigger delete webhooks
        execute_delete_webhooks unless embedded?
      end

      def set_data_hash(**) # rubocop:disable Naming/AccessorMethodName
        options = DataCycleCore::Content::DataHashOptions.new(**)
        options.data_hash.slice!(*writable_property_names) # remove all keys that are not part of the schema

        return no_changes(options.ui_locale) if options.data_hash.blank? && !options.force_update

        # set cache_valid_since before callbacks for default_value and computed, so it can be used in the callbacks (e.g. for imgproxy_signature)
        self.cache_valid_since = options.save_time

        before_save_data_hash(options)

        partial_schema = schema.deep_dup
        partial_keys = options.data_hash.keys
        partial_keys = partial_keys.concat(required_property_names).uniq if options.new_content # validate required fields for new contents
        partial_schema['properties'].slice!(*partial_keys)
        options.data_hash.deep_freeze # ensure data_hash doesn't get changed

        return false unless validate(data_hash: options.data_hash, schema_hash: partial_schema, current_user: options.current_user, strict: options.new_content)

        unless options.force_update
          differ = diff_obj(options.data_hash, partial_schema)
          return no_changes(options.ui_locale) if differ.diff_hash.blank? && differ.errors[:error].blank?

          self.datahash_changes = differ.diff_hash.deep_dup
          partial_schema['properties']&.slice!(*differ.diff_hash.keys)
        end

        transaction(joinable: false, requires_new: true) do
          to_history if write_history
          self.write_history = !options.prevent_history

          set_template_data_hash(options, partial_schema&.dig('properties') || property_definitions)

          self.updated_at = options.save_time
          self.updated_by = options.current_user&.id
          self.last_updated_locale = I18n.locale
          self.version_name = options.version_name.presence

          if id.nil?
            self.created_at = options.save_time
            self.created_by = options.current_user&.id
          end

          save(touch: false)
          search_languages(options.update_search_all) unless id.nil?
        end

        reload
        after_save_data_hash(options)

        true
      end

      def set_data_hash_with_translations(**) # rubocop:disable Naming/AccessorMethodName
        options = DataCycleCore::Content::DataHashOptions.new(**)
        return {} if options.data_hash.blank? && !options.force_update

        translations = DataCycleCore::DataHashService.parse_translated_hash(options.data_hash, available_locales)
        version_name = (options.data_hash.key?(:version_name) ? options.data_hash[:version_name] : options.version_name).presence
        locale, datahash = translations.shift

        transaction(joinable: false, requires_new: true) do
          I18n.with_locale(locale) do
            raise ActiveRecord::Rollback unless set_data_hash(**options.to_h, data_hash: datahash, version_name: version_name&.+(" (#{I18n.locale})"))
          end

          if translations.present?
            translations.each do |l, locale_hash|
              I18n.with_locale(l) do
                raise ActiveRecord::Rollback unless set_data_hash(**options.to_h.slice(:current_user, :ui_locale, :prevent_history, :source, :force_update), data_hash: locale_hash, update_search_all: false, version_name: version_name&.+(" (#{I18n.locale})"))
              end
            end

            no_changes_key = translated_template_name(options.ui_locale).to_sym
            i18n_warnings.each_value { |w| w.delete(no_changes_key) } unless translations.keys.push(locale).all? { |l| i18n_warnings[l]&.include?(no_changes_key) }
          end

          if computed_property_names.intersect?(translatable_property_names)
            add_update_translated_computed_properties_job(
              available_locales.map(&:to_s) - translations.keys - [locale]
            )
          end
        end

        i18n_valid?
      end

      def inherit_source_attributes(data_hash:, source:)
        I18n.with_locale(source.first_available_locale) do
          data_hash.reverse_merge!(source.get_data_hash_partial(DataCycleCore.inheritable_attributes))
        end
      end

      def execute_create_webhooks
        return if prevent_webhooks.is_a?(TrueClass)

        DataCycleCore::Webhook::Create.execute_all(self)
      end

      def execute_update_webhooks
        return if prevent_webhooks.is_a?(TrueClass)

        DataCycleCore::Webhook::Update.execute_all(self)
      end

      def execute_delete_webhooks
        return if prevent_webhooks.is_a?(TrueClass)

        DataCycleCore::Webhook::Delete.execute_all(self)
      end

      def validate(data_hash:, schema_hash: nil, strict: false, add_defaults: false, current_user: nil, add_warnings: true, add_errors: true) # rubocop:disable Naming/PredicateMethod
        data_hash = add_default_values(data_hash:, current_user:, partial: !strict).dup if add_defaults && default_value_property_names.present?

        validator = DataCycleCore::MasterData::ValidateData.new(self)
        valid = DataCycleCore::LocalizationService.localize_validation_errors(validator.validate(data_hash, schema_hash || schema, strict), current_user&.ui_locale || DataCycleCore.ui_locales.first)

        valid[:warning]&.each { |k, v| Array.wrap(v).each { |e| warnings.add(k, e) } } if valid[:warning].present? && add_warnings

        if valid[:error].present?
          valid[:error].each { |k, v| v.each { |e| errors.add(k, e) } } if add_errors

          return false
        end

        true
      end

      def set_internal_data
        self.content_type = schema&.dig('content_type')
        self.boost = schema&.dig('boost') || 1.0
        validity_hash = metadata.nil? ? nil : metadata['validity_period']
        self.validity_range = get_validity_range(validity_hash)
      end

      def add_related_cache_invalidation_job
        DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'invalidate_related_cache')
      end

      def add_update_exif_values_job
        DataCycleCore::WriteExifDataJob.perform_later(id)
      end

      def add_update_dependent_computed_properties_job
        DataCycleCore::UpdateComputedPropertiesJob.perform_later(id, Array.wrap(datahash_changes&.keys))
      end

      def add_update_translated_computed_properties_job(locales)
        return if locales.blank?

        DataCycleCore::UpdateTranslatedComputedPropertiesJob.perform_later(id, Array.wrap(locales))
      end

      def invalidate_self_and_update_search
        search_languages(true)
        invalidate_self
      end

      def invalidate_self
        update_columns(cache_valid_since: Time.zone.now)
        invalidate_related_cache
      end

      def invalidate_related_cache
        cached_related_contents.invalidate_all
      end

      def self.invalidate_all
        ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
          ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

          unscoped
            .where(
              id: unscoped.where(id: all.except(:distinct).order(id: :asc).select(:id))
                .lock('FOR UPDATE SKIP LOCKED')
                .select(:id)
            )
            .update_all(cache_valid_since: Time.zone.now)
        end
      end

      def self.update_search_all
        all.find_each { |t| t.search_languages(true) }
      end

      private

      def no_changes(locale) # rubocop:disable Naming/PredicateMethod
        warnings&.add(translated_template_name(locale), I18n.t('controllers.warning.no_changes', locale:))

        true
      end

      def attribute_blank?(data_hash, key, _defininition = nil)
        # BUG: if used on content in new language, translated_locales will include the new language after this method call
        return true if key.blank?

        data_hash[key].blank? &&
          !data_hash[key].is_a?(FalseClass) &&
          try(key).blank? &&
          !try(key).is_a?(FalseClass)
      end

      def notify_subscribers(current_user:)
        subscriptions.except_user_id(current_user.id).to_notify(version_name.present? && DataCycleCore::Feature::NamedVersion.enabled? ? ['always', 'named_version'] : ['always']).presence&.each do |subscription|
          DataCycleCore::SubscriptionMailer.notify(subscription.user, [id]).deliver_later
        end
      end

      def set_template_data_hash(options, properties)
        properties.each do |key, value|
          storage_cases_set(options, key, value)
        end
      end

      def storage_cases_set(options, key, properties)
        return if virtual_property_names.include?(key)

        value = options.data_hash[key]
        # puts "#{key}, #{value}, #{properties.dig('type')}"
        case properties['type']
        when *SLUG_PROPERTY_TYPES
          save_slug(key, value)
        when 'key'
          true # do nothing
        when *LINKED_PROPERTY_TYPES
          set_linked(key, value, properties)
        when *EMBEDDED_PROPERTY_TYPES
          set_embedded(key, value, properties['template_name'], properties['translated'], options)
        when *SIMPLE_OBJECT_PROPERTY_TYPES, *PLAIN_PROPERTY_TYPES, *TABLE_PROPERTY_TYPES, *OEMBED_PROPERTY_TYPES
          save_values(key, value, properties)
        when *CLASSIFICATION_PROPERTY_TYPES
          set_classification_relation_ids(value, key, properties['tree_label'], properties['default_value'], properties['not_translated'], properties['universal'])
        when *ASSET_PROPERTY_TYPES
          set_asset_id(value, key, properties['asset_type'])
        when *SCHEDULE_PROPERTY_TYPES
          set_schedule(value, key)
        when *COLLECTION_PROPERTY_TYPES
          set_collection_links(key, value)
        when *GEO_PROPERTY_TYPES
          set_geographic(key, value, properties)
        when *TIMESERIES_PROPERTY_TYPES
          set_timeseries(key, value)
        end
      end

      def save_slug(key, value)
        send(:"#{key}=", convert_to_type('slug', value))
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
        save_data = normalize_value(value, properties)
        save_data = convert_to_type(properties['type'], save_data, properties) if properties['type'].in?(['geographic', 'string'])
        send(:"#{key}=", save_data)
      end

      def normalize_value(value, properties)
        norm_value = value
        return DataCycleCore::MasterData::DataConverter.string_to_string(norm_value, properties) if properties['type'] == 'string'
        norm_value
      end

      def save_to_jsonb(key, data, properties, location)
        save_data = data.deep_dup
        save_data = set_data_tree_hash(save_data, properties['properties'], location, properties) if properties['type'] == 'object'
        save_data = convert_to_string(properties['type'], normalize_value(save_data, properties), properties) if PLAIN_PROPERTY_TYPES.include?(properties['type'])

        if send(location.to_s).blank? # set to json field (could be empty)
          send(:"#{location}=", { key => save_data })
        else
          send(location.to_s).method(:[]=).call(key, save_data)
        end
      end

      def set_data_tree_hash(data, data_definitions, location, properties)
        data_hash = {}
        data_definitions.each_key do |key|
          if data_definitions[key]['type'] == 'object'
            data_hash[key] = set_data_tree_hash(data&.dig(key), data_definitions[key]['properties'], location, properties)
          elsif (data_definitions[key]['storage_location'] == 'value' && location == 'metadata') || (data_definitions[key]['storage_location'] == 'translated_value' && location == 'content')
            data_hash[key] = convert_to_string(data_definitions[key]['type'], normalize_value(data&.dig(key), data_definitions[key]), properties)
          elsif data_definitions[key]['storage_location'] == 'column'
            save_to_column(key, data&.dig(key), data_definitions[key])
          end
        end
        data_hash
      end

      # format [{ 'timestamp' => Time, 'value' => 1 }, { 'timestamp' => Time, 'value' => 2 }]
      def set_timeseries(key, value)
        return if value.blank?

        data = value.map do |item|
          v = item.with_indifferent_access.slice('timestamp', 'value')
          {
            thing_id: id,
            property: key,
            **v
          }
        end

        Timeseries.insert_all(data, unique_by: :thing_attribute_timestamp_idx, returning: :thing_id)
      end

      def set_linked(field_name, input_data, properties)
        return if properties['link_direction'] == 'inverse' # inverse direction is read_only
        relation_b = properties['inverse_of']

        item_ids_before_update = send(field_name).pluck(:id)
        item_ids_after_update = parse_linked_ids(input_data)

        raise ArgumentError, 'linked id cannot be the same as the id of the content' if item_ids_after_update.include?(id)

        if DataCycleCore::DataHashService.present?(item_ids_after_update)
          content_content_a.upsert_all(
            item_ids_after_update
              .map
              .with_index do |content_b_id, index|
                { relation_a: field_name, content_b_id:, order_a: index, relation_b:, updated_at: Time.zone.now }
              end,
            unique_by: :by_content_relation_a
          )
        end

        to_delete = item_ids_before_update - item_ids_after_update

        return if to_delete.empty?

        content_content_a.where(relation_a: field_name, content_b_id: to_delete).delete_all
      end

      def parse_linked_ids(a)
        return [] if is_blank?(a)
        data = a.is_a?(::String) ? [a] : a
        data = a&.pluck(:id) if data.is_a?(ActiveRecord::Relation)
        raise ArgumentError, 'expected a uuid or list of uuids' unless data.is_a?(::Array)
        data
      end

      def set_collection_links(field_name, input_data)
        item_ids_before_update = send(field_name).pluck(:id)
        item_ids_after_update = parse_collection_ids(input_data, field_name)

        content_collection_links.upsert_all(item_ids_after_update, unique_by: :ccl_unique_index) if DataCycleCore::DataHashService.present?(item_ids_after_update)

        to_delete = item_ids_before_update - item_ids_after_update.pluck(:collection_id)

        return if to_delete.empty?

        content_collection_links.where(relation: field_name, collection_id: to_delete).delete_all
      end

      def set_geographic(field_name, input_data, properties)
        value = string_to_geographic(input_data)

        # use detect for force load all geometries
        return geometries.detect { |g| g.relation == field_name }&.mark_for_destruction if value.blank?

        if (existing = geometries.detect { |g| g.relation == field_name }).present?
          existing.geom = value
        else
          geometries.build(relation: field_name, geom: value, priority: properties['priority'])
        end
      end

      def parse_collection_ids(a, key)
        ids = Array.wrap(a).compact

        return ids.map.with_index { |c, index| { collection_id: c.id, relation: key, order_a: index } } if ids.all?(ActiveRecord::Base)

        DataCycleCore::Collection.by_ordered_values(ids).map.with_index { |c, index| { collection_id: c.id, relation: key, order_a: index } }
      end

      def set_embedded(field_name, input_data, name, translated, options)
        updated_item_keys = []
        available_update_item_keys = load_embedded_objects(field_name, nil, !translated).pluck(:id).uniq
        data = input_data || []

        data.each_index do |index|
          item = data[index]
          item_id = item&.dig('datahash', 'id') || item&.dig('id')

          if item_id.present?
            if item['datahash']&.keys&.except('id')&.any? ||
               item['translations']&.values&.any? { |v| v.keys.except('id').any? } ||
               item.keys.except('id').any?
              upsert_content(name, item, options)
            end

            if available_update_item_keys[index] != item_id
              upsert_relation = DataCycleCore::ContentContent.find_or_create_by!({
                content_a_id: id,
                relation_a: field_name,
                content_b_id: item_id
              })
              upsert_relation.order_a = index
              upsert_relation.save
            end

            updated_item_keys << item_id
          else
            insert_item = upsert_content(name, item, options)
            DataCycleCore::ContentContent.create!({
              content_a_id: id,
              relation_a: field_name,
              order_a: index,
              content_b_id: insert_item.id
            })
            updated_item_keys << insert_item.id
          end
        end

        to_delete = available_update_item_keys - updated_item_keys
        return if to_delete.blank?

        content_content_a.where(relation_a: field_name, content_b_id: to_delete).delete_all
        DataCycleCore::Thing
          .where(id: to_delete)
          .find_each do |item|
          item.destroy(
            current_user: options.current_user,
            save_time: options.save_time,
            check_ancestors: true
          )
        end
      end

      def upsert_content(name, item, options)
        item_id = item&.dig('datahash', 'id') || item&.dig('id')
        template_name = name
        if template_name.is_a?(Array)
          specific_template_name = item&.dig('datahash', 'template_name').presence || item&.dig('template_name')
          raise DataCycleCore::Error::TemplateNotAllowedError.new(specific_template_name, template_name) unless template_name.include?(specific_template_name)

          template_name = specific_template_name
        end

        upsert_item = if item_id.present?
                        DataCycleCore::Thing.find_by(id: item_id) ||
                          DataCycleCore::Thing.new(id: item_id, template_name:)
                      else
                        DataCycleCore::Thing.new(template_name:)
                      end
        # TODO: check if external_source_id is required
        upsert_item.external_source_id = external_source_id
        created = upsert_item.new_record?
        upsert_item.created_at = options.save_time if created
        upsert_item.save

        upsert_item.set_data_hash_with_translations(
          data_hash: item,
          current_user: options.current_user,
          save_time: options.save_time,
          prevent_history: true,
          new_content: created
        )

        upsert_item
      end

      def set_classification_relation_ids(ids, relation_name, _tree_label, default_value, not_translated, _universal)
        return if not_translated && I18n.default_locale != I18n.locale && default_value.blank?

        present_relation_ids = send(relation_name).pluck(:id)
        ids = Array.wrap(ids).uniq

        if DataCycleCore::DataHashService.present?(ids)
          classification_contents.upsert_all(
            ids.map do |classification_id|
              {
                classification_id:,
                relation: relation_name,
                updated_at: Time.zone.now
              }
            end,
            unique_by: :index_classification_contents_on_unique_constraint
          )
        end

        to_delete = present_relation_ids - ids

        return if to_delete.empty?

        classification_contents.where(relation: relation_name, classification_id: to_delete).delete_all
      end

      def set_asset_id(asset_id, relation_name, asset_type)
        asset_id = asset_id.first.id if asset_id.is_a?(ActiveRecord::Relation) || asset_id.is_a?(::Array)
        asset_id = asset_id.id if asset_id.is_a?(DataCycleCore::Asset)
        old_ids = load_asset_relation(relation_name).pluck(:id)
        to_delete = old_ids - Array.wrap(asset_id)

        if to_delete.present?
          asset_contents
            .with_assets(to_delete, asset_type)
            .with_relation(relation_name)
            .destroy_all
        end

        return unless id.present? && asset_id.present?

        DataCycleCore::AssetContent.find_or_create_by(
          thing_id: id,
          asset_id:,
          asset_type:,
          relation: relation_name
        )
      end

      def set_schedule(input_data, relation_name)
        updated_item_keys = []
        available_items = load_schedule(relation_name).pluck(:id)

        input_data&.each do |item|
          schedule = if item['id'].present?
                       DataCycleCore::Schedule.find_or_initialize_by(id: item['id'])
                     else
                       DataCycleCore::Schedule.new
                     end
          schedule.external_source_id = item['external_source_id'] if item['external_source_id'].present?
          schedule.external_key = item['external_key'] if item['external_key'].present?
          schedule.thing_id = id
          schedule.relation = relation_name
          schedule.holidays = item['holidays']
          schedule.from_hash(item.with_indifferent_access)
          schedule.save!
          updated_item_keys << schedule.id
        end

        to_delete = available_items - updated_item_keys

        return if to_delete.empty?

        DataCycleCore::Schedule.where(id: to_delete).destroy_all
      end
    end
  end
end
