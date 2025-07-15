# frozen_string_literal: true

# The Turbo throttler causes threads to run in the background
# which can break transactional tests. Disable it.
module DataCycleCore
  module DisableTurboThrottler
    def throttle(&)
      yield
    end
  end
end

DataCycleCore::Turbo::Throttler.prepend(DataCycleCore::DisableTurboThrottler)
