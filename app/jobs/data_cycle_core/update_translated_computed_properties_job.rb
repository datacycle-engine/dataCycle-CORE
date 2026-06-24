# frozen_string_literal: true

module DataCycleCore
  class UpdateTranslatedComputedPropertiesJob < UniqueApplicationJob
    queue_as :cache_invalidation

    def delayed_reference_id
      "#{arguments[0]}-#{arguments[1].join('_')}-#{arguments[2]&.join('_')}"
    end

    def perform(id, locales, keys = nil)
      content = DataCycleCore::Thing.find_by(id:)

      return if content.nil?

      update_computed_properties(content, locales, keys)
    end

    private

    def update_computed_properties(content, locales, keys)
      return if keys.blank? || locales.blank?

      computed_keys = content.computed_property_names.intersection(keys)
      computed_keys = computed_keys.intersection(content.translatable_property_names)

      return if computed_keys.blank?

      content.available_locales.map(&:to_s).intersection(locales).each do |locale|
        content.update_computed_values_for_locale(keys: computed_keys, locale: locale)
      end
    end
  end
end
