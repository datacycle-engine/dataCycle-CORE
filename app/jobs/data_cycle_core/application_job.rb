# frozen_string_literal: true

module DataCycleCore
  class ApplicationJob < ActiveJob::Base
    include DataCycleCore::JobExtensions::DelayedJob

    retry_on StandardError, attempts: 10, wait: :exponentially_longer
  end
end
