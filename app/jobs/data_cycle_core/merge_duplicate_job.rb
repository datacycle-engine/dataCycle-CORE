# frozen_string_literal: true

module DataCycleCore
  class MergeDuplicateJob < UniqueApplicationJob
    queue_as :default
    limits_concurrency key: ->(*args) { "#{args[0]}/#{args[1]}" }

    # merges triggered by a user run inline (see Feature::ControllerFunctions::DuplicateCandidate),
    # this job is the fallback for big merges and for merges that failed part way through
    def perform(original_id, duplicate_id, current_user_id = nil)
      return if duplicate_id.blank? || original_id.blank?

      Feature::DuplicateCandidate.merge_duplicate(
        Thing.find_by(id: original_id),
        Thing.find_by(id: duplicate_id),
        current_user: current_user_id.present? ? User.find_by(id: current_user_id) : nil
      )
    end
  end
end
