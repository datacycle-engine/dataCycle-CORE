# frozen_string_literal: true

module DataCycleCore
  class ComputePropertiesJob < UniqueApplicationJob
    queue_as :search_update
    limits_concurrency key: ->(*args) { "#{args[0]}/#{Array.wrap(args[1]).join(',')}" }

    def perform(id, keys)
      return if keys.blank?

      content = DataCycleCore::Thing.find(id)
      content.update_computed_values(keys: keys)
    end
  end
end
