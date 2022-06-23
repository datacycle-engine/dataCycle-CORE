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

          def count(virtual_definition:, content:, **_args)
            calculate(content, virtual_definition.dig('virtual', 'data'), :count)
          end

          def sum(virtual_definition:, content:, **_args)
            calculate(content, virtual_definition.dig('virtual', 'data'), :sum)
          end

          def avg(virtual_definition:, content:, **_args)
            calculate(content, virtual_definition.dig('virtual', 'data'), :average)
          end

          def calculate(content, data, method)
            content&.send(data)&.send(method, :value)&.to_f
          end
        end
      end
    end
  end
end
