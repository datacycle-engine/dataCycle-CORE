# frozen_string_literal: true

module DataCycleCore
  class DestroyDependentForDuplicatesJob < CheckDependentForDuplicatesJob
    def perform(_content_id, id_attribute_hash)
      return if id_attribute_hash.present?

      check_relevant_things(id_attribute_hash)
    end
  end
end
