# frozen_string_literal: true

module DataCycleCore
  class CheckForDuplicatesJob < ApplicationJob
    queue_as :default

    def perform(id)
      return unless DataCycleCore::Feature::DuplicateCandidate.enabled?

      DataCycleCore::Thing.find_by(id: id)&.create_duplicate_candidates
    end

    around_enqueue do |_job, block|
      block.call unless Delayed::Job.exists?(queue: queue_name, delayed_reference_type: delayed_reference_type, delayed_reference_id: delayed_reference_id(*arguments), locked_at: nil)
    end

    def priority
      5
    end

    after_enqueue do |job|
      Delayed::Job.find_by(id: job.provider_job_id)&.update_columns(delayed_reference_id: delayed_reference_id(*arguments), delayed_reference_type: delayed_reference_type)
    end

    def delayed_reference_id(content_id)
      "#{content_id}/check_for_duplicates"
    end

    def delayed_reference_type
      'DataCycleCore::Thing'
    end
  end
end
