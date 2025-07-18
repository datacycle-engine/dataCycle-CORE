# frozen_string_literal: true

# The Turbo debouncer causes threads to run in the background
# which can break transactional tests. Disable it.
module DataCycleCore
  module DisableTurboDebouncer
    def debounce(&)
      yield
    end
  end
end

Turbo::Debouncer.prepend(DataCycleCore::DisableTurboDebouncer)
