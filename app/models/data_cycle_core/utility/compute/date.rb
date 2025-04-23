# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Date
        class << self
          def latest_timestamp_from_timeseries(computed_parameters:, content:, **_args)
            latest_timestamp = nil
            params = computed_parameters.keys
            params.each do |param|
              timestamps = content.send(param)
              next if timestamps.blank?

              last_timestamp = timestamps.last&.timestamp
              next if last_timestamp.blank?

              latest_timestamp = last_timestamp if latest_timestamp.nil? || last_timestamp > latest_timestamp
            end
            latest_timestamp
          end
        end
      end
    end
  end
end
