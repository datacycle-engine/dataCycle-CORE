# frozen_string_literal: true

module DataCycleCore
  class UpdateAsyncComputedPropertiesJob < UniqueApplicationJob
    queue_as :cache_invalidation
    queue_with_priority 10
    limits_concurrency key: ->(*args) { "#{args[0]}/#{Array.wrap(args[1]).join(',')}/#{args[2]}" }

    def perform(id, keys, locale = nil)
      return if keys.blank?

      content = DataCycleCore::Thing.find(id)
      computed_keys = keys.intersection(content.async_computed_property_names)
      return if computed_keys.blank?

      content.update_computed_values_for_locale(keys: computed_keys, locale:)
    end
  end
end
