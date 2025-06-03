# frozen_string_literal: true

module DataCycleCore
  class RemoveContentReferencesFromTestJob < UniqueApplicationJob
    PRIORITY = 10

    queue_as :cache_invalidation

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      self.class.name.demodulize
    end

    def perform(id, content_ids)
      DataCycleCore::Thing
        .where(id: content_ids)
        .find_each { |thing| remove_ids_from_test(thing, id) }
    end

    private

    def update_computed_properties(content, id)
      if content.computed_property_names.intersect?(content.translatable_property_names)
        content.available_locales.each do |locale|
          translated_computed_keys = content.computed_property_names.intersection(content.translatable_property_names)

          data_hash = {}
          keys = locale == content.first_available_locale ? content.computed_property_names : translated_computed_keys

          I18n.with_locale(locale) do
            content.add_computed_values(data_hash:, keys:, force: true)
            content.webhook_priority = WEBHOOK_PRIORITY
            content.set_data_hash(data_hash:, update_computed: false)
          end
        end
      else
        I18n.with_locale(content.first_available_locale) do
          data_hash = {}
          content.add_computed_values(data_hash:, force: true)
          content.webhook_priority = WEBHOOK_PRIORITY
          content.set_data_hash(data_hash:, update_computed: false)
        end
      end
    end
  end
end
