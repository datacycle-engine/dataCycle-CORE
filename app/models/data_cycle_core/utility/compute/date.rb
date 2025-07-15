# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Date
        class << self
          def latest_timestamp_from_timeseries(computed_parameters:, content:, **_args)
            timestamps = []

            computed_parameters.each_value do |value|
              timestamps << value&.last&.dig('timestamp')
            end

            # needed for task update_computed
            if timestamps.compact.blank?
              computed_parameters.each_key do |key|
                timestamps << content.send(key)&.last&.timestamp
              end
            end

            timestamps.compact.max&.in_time_zone
          end
        end
      end
    end
  end
end
