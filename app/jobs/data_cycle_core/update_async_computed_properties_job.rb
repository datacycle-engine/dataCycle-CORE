# frozen_string_literal: true

module DataCycleCore
  class UpdateAsyncComputedPropertiesJob < UniqueApplicationJob
    PRIORITY = 10

    queue_as :cache_invalidation

    def priority
      PRIORITY
    end

    def delayed_reference_id
      "#{arguments[0]}-#{Array.wrap(arguments[1]).join('_')}-#{arguments[2]}"
    end

    def perform(id, keys, locale = nil)
      return if keys.blank?

      content = DataCycleCore::Thing.find(id)
      computed_keys = keys.intersection(content.async_computed_property_names)
      return if computed_keys.blank?

      content.update_computed_values_for_locale(keys: computed_keys, locale:)
    end
  end
end
