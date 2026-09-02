# frozen_string_literal: true

module DataCycleCore
  class CheckForDuplicatesJob < UniqueApplicationJob
    queue_as :search_update
    queue_with_priority 5
    limits_concurrency key: ->(*args) { args[0] }

    def perform(id)
      return unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      DataCycleCore::Thing.find_by(id:)&.create_duplicate_candidates
    end
  end
end
