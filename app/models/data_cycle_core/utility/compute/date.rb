# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Date
        class << self
          def latest_timestamp_from_timeseries(computed_parameters:, content:, **_args)
            timestamps = []

            computed_parameters.each_key do |key|
              timestamps << content.send(key)&.last&.timestamp
            end

            timestamps.compact.max
          end
        end
      end
    end
  end
end
