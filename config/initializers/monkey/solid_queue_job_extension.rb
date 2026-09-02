# frozen_string_literal: true

module DataCycleCore
  module SolidQueueJobExtension
    extend ActiveSupport::Concern

    included do
      # Jobs that still have something ahead of them: scheduled, ready, blocked or claimed.
      #
      # Finished jobs are destroyed (+preserve_finished_jobs = false+), so a failed execution is the
      # only thing that keeps a row around indefinitely — and a permanently failed job is done, not
      # pending. Without this filter such a row makes its content look forever "queued" and blocks
      # every later job for the same concurrency key.
      scope :live, -> { where(finished_at: nil).where.missing(:failed_execution) }
    end
  end
end

Rails.application.reloader.to_prepare do
  SolidQueue::Job.include(DataCycleCore::SolidQueueJobExtension)
end
