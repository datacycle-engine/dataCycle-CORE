# frozen_string_literal: true

# won't be reported to AppSignal
module DataCycleCore
  module Generic
    module Common
      module Error
        class GenericSilentError < StandardError
        end
      end
    end
  end
end
