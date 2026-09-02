# frozen_string_literal: true

module DataCycleCore
  class ApplicationJob < ActiveJob::Base
    include DataCycleCore::JobExtensions::Persistence
    include DataCycleCore::JobExtensions::Callbacks

    queue_with_priority 5
  end
end
