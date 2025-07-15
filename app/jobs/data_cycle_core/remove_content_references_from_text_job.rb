# frozen_string_literal: true

module DataCycleCore
  class RemoveContentReferencesFromTextJob < UniqueApplicationJob
    PRIORITY = 10

    queue_as :cache_invalidation

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def perform(id, content_ids)
      DataCycleCore::Thing
        .where(id: content_ids)
        .find_each { |thing| remove_ids_from_test(thing, id) }
    end

    private

    def remove_ids_from_test(thing, linked_id)
      if thing.text_with_linked_property_names.intersect?(thing.translatable_property_names)
        thing.available_locales.each do |locale|
          translated_text_keys = thing.text_with_linked_property_names.intersection(thing.translatable_property_names)

          data_hash = {}
          keys = locale == thing.first_available_locale ? thing.text_with_linked_property_names : translated_text_keys

          I18n.with_locale(locale) do
            thing.remove_id_from_text_props(data_hash:, linked_id:, keys:)
            thing.set_data_hash(data_hash:)
          end
        end
      else
        I18n.with_locale(thing.first_available_locale) do
          data_hash = {}
          thing.remove_id_from_text_props(data_hash:, linked_id:)
          thing.set_data_hash(data_hash:)
        end
      end
    end
  end
end
