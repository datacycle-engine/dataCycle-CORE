# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Date
        class << self
          def beginning_of_day(**_args)
            Time.zone.now.beginning_of_day.to_s
          end
        end
      end
    end
  end
end
