# frozen_string_literal: true

module DataCycleCore
  class ApplicationJob < ActiveJob::Base
    include DataCycleCore::JobExtensions::DelayedJob
    include DataCycleCore::JobExtensions::Callbacks

    ATTEMPTS = 10
    WAIT = :exponentially_longer
    PRIORITY = 5

    queue_with_priority self::PRIORITY
  end
end
