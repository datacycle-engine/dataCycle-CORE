# frozen_string_literal: true

module DataCycleCore
  class UpdateTranslatedComputedPropertiesJob < UniqueApplicationJob
    REFERENCE_TYPE = 'update_translated_computed_properties'

    queue_as :cache_invalidation

    def delayed_reference_id
      "#{arguments[0]}-#{arguments[1].join('_')}"
    end

    def delayed_reference_type
      REFERENCE_TYPE
    end

    def perform(id, locales)
      content = DataCycleCore::Thing.find_by(id:)

      return if content.nil?

      update_computed_properties(content, locales)
    end

    private

    def update_computed_properties(content, locales)
      return unless content.computed_property_names.intersect?(content.translatable_property_names)

      content.available_locales.map(&:to_s).intersection(locales).each do |locale|
        translated_computed_keys = content.computed_property_names.intersection(content.translatable_property_names)

        I18n.with_locale(locale) do
          data_hash = {}
          content.add_computed_values(data_hash:, keys: translated_computed_keys, force: true)
          content.set_data_hash(data_hash:, update_computed: false)
        end
      end
    end
  end
end
