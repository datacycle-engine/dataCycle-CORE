# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Timeseries
        class << self
          def first(virtual_definition:, content:, **_args)
            content&.send(virtual_definition.dig('virtual', 'data'))&.first&.send(:value)
          end

          def last(virtual_definition:, content:, **_args)
            content&.send(virtual_definition.dig('virtual', 'data'))&.last&.send(:value)
          end

          def min(virtual_definition:, content:, **_args)
            calculate(content, virtual_definition.dig('virtual', 'data'), :minimum)
          end

          def max(virtual_definition:, content:, **_args)
            calculate(content, virtual_definition.dig('virtual', 'data'), :maximum)
          end

          # weighted by redundant_count, not a plain row count: a collapsed run's raw
          # datapoints are only physically stored as 2 rows (see RedundantValueCollapser),
          # so counting rows would undercount. redundant_count defaults to 1 everywhere,
          # so this is unchanged for timeseries that never collapse anything.
          def count(virtual_definition:, content:, **_args)
            weighted_count(content, virtual_definition.dig('virtual', 'data'))
          end

          # weighted by redundant_count; correct because every value within a collapsed
          # run is identical, so the end row's value * redundant_count alone already
          # equals the sum of all the run's (identical) raw values
          def sum(virtual_definition:, content:, **_args)
            weighted_sum(content, virtual_definition.dig('virtual', 'data'))
          end

          def avg(virtual_definition:, content:, **_args)
            data = virtual_definition.dig('virtual', 'data')
            count = weighted_count(content, data)

            return if count.blank? || count.zero?

            weighted_sum(content, data) / count
          end

          def calculate(content, data, method)
            content&.send(data)&.send(method, :value)&.to_f
          end

          # excludes NULL-value rows, matching the old COUNT(value)'s NULL-skipping
          # behavior - SUM(redundant_count) alone would count them too, since
          # redundant_count itself is never NULL regardless of value
          def weighted_count(content, data)
            content&.send(data)&.where&.not(value: nil)&.sum(:redundant_count)&.to_f
          end

          def weighted_sum(content, data)
            content&.send(data)&.sum('value * redundant_count')&.to_f
          end
        end
      end
    end
  end
end
