# frozen_string_literal: true

module DataCycleCore
  class ComputePropertiesJob < UniqueApplicationJob
    REFERENCE_TYPE = 'compute_properties'

    queue_as :search_update

    def delayed_reference_id
      "#{arguments[0]}-#{Array.wrap(arguments[1]).join('_')}"
    end

    def delayed_reference_type
      REFERENCE_TYPE
    end

    def perform(id, keys)
      return if keys.blank?

      content = DataCycleCore::Thing.find(id)
      content.update_computed_values(keys: keys)
    end
  end
end
