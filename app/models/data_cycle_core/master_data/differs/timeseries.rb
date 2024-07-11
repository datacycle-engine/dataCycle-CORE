# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Timeseries < Basic
        def diff(_a, b, *)
          series_b = normalize_timeseries(b)

          return if series_b.blank?

          @diff_hash = ['+', series_b]
        end

        private

        def normalize_timeseries(data)
          return [] if data.blank?

          data.map { |item|
            next if item.blank?

            if item.is_a?(Timeseries)
              { timestamp: item.timestamp, value: item.value }
            else
              v = item.symbolize_keys
              { timestamp: v[:timestamp].in_time_zone.floor(3), value: v[:value].to_f }
            end
          }.compact
        end
      end
    end
  end
end
