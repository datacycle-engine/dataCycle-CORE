# frozen_string_literal: true

module DataCycleCore
  class ApplicationJob < ActiveJob::Base
    include DataCycleCore::JobExtensions::DelayedJob
    include DataCycleCore::JobExtensions::Callbacks

    ATTEMPTS = 10
    WAIT = :exponentially_longer
  end
end
