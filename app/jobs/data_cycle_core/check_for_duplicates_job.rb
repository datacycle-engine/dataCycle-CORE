# frozen_string_literal: true

module DataCycleCore
  class CheckForDuplicatesJob < UniqueApplicationJob
    PRIORITY = 5

    REFERENCE_TYPE = 'check_for_duplicates'

    queue_as :default

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      REFERENCE_TYPE
    end

    def perform(id)
      return unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      DataCycleCore::Thing.find_by(id:)&.create_duplicate_candidates
    end
  end
end
