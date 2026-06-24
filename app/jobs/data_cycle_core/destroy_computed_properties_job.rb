# frozen_string_literal: true

module DataCycleCore
  class DestroyComputedPropertiesJob < UpdateComputedPropertiesJob
    def perform(_content_id, id_attribute_hash)
      return if id_attribute_hash.blank?

      update_relevant_things(id_attribute_hash)
    end
  end
end
