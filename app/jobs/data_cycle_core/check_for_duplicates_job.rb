# frozen_string_literal: true

module DataCycleCore
  class CheckForDuplicatesJob < UniqueApplicationJob
    PRIORITY = 5

    queue_as :default

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def perform(id)
      return unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      DataCycleCore::Thing.find_by(id:)&.create_duplicate_candidates
    end
  end
end
