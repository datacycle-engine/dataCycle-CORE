# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Timeseries
        class << self
          def first(virtual_parameters:, content:, **_args)
            content&.send(virtual_parameters.dig('virtual', 'data'))&.first&.send(:value)
          end

          def last(virtual_parameters:, content:, **_args)
            content&.send(virtual_parameters.dig('virtual', 'data'))&.last&.send(:value)
          end

          def min(virtual_parameters:, content:, **_args)
            calculate(content, virtual_parameters.dig('virtual', 'data'), :minimum)
          end

          def max(virtual_parameters:, content:, **_args)
            calculate(content, virtual_parameters.dig('virtual', 'data'), :maximum)
          end

          def count(virtual_parameters:, content:, **_args)
            calculate(content, virtual_parameters.dig('virtual', 'data'), :count)
          end

          def sum(virtual_parameters:, content:, **_args)
            calculate(content, virtual_parameters.dig('virtual', 'data'), :sum)
          end

          def avg(virtual_parameters:, content:, **_args)
            calculate(content, virtual_parameters.dig('virtual', 'data'), :average)
          end

          def calculate(content, data, method)
            content&.send(data)&.send(method, :value)
          end
        end
      end
    end
  end
end
