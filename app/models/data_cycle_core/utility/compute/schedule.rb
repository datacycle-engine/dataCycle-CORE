# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Schedule
        class << self
          def start_date(**args)
            args[:computed_parameters]&.first&.map { |e| e&.dig(:start_time, :time)&.in_time_zone }&.compact&.sort&.first
          end

          def end_date(**args)
            tmp = args[:computed_parameters]&.first&.map { |e| e&.dig(:rrules, 0)&.has_key?(:until) ? (e&.dig(:rrules, 0, :until).presence || DateTime::Infinity.new) : e&.dig(:start_time, :time)&.in_time_zone&.+(e&.dig(:duration)) }&.compact&.sort&.last

            return nil if tmp.is_a?(DateTime::Infinity)

            tmp
          end
        end
      end
    end
  end
end
