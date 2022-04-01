# frozen_string_literal: true

module DataCycleCore
  class ApplicationJob < ActiveJob::Base
    include DataCycleCore::JobExtensions::DelayedJob
  end
end
