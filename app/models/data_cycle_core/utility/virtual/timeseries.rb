# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Timeseries
        class << self
          def first(**args)
            virtual_parameters = args.dig(:virtual_definition)
            content = args.dig(:content)
            content&.send(virtual_parameters.dig('virtual', 'data'))&.first&.send(:value)
          end

          def last(**args)
            virtual_parameters = args.dig(:virtual_definition)
            content = args.dig(:content)
            content&.send(virtual_parameters.dig('virtual', 'data'))&.last&.send(:value)
          end

          def min(**args)
            virtual_parameters = args.dig(:virtual_definition)
            content = args.dig(:content)
            calculate(content, virtual_parameters.dig('virtual', 'data'), :minimum)
          end

          def max(**args)
            virtual_parameters = args.dig(:virtual_definition)
            content = args.dig(:content)
            calculate(content, virtual_parameters.dig('virtual', 'data'), :maximum)
          end

          def count(**args)
            virtual_parameters = args.dig(:virtual_definition)
            content = args.dig(:content)
            calculate(content, virtual_parameters.dig('virtual', 'data'), :count)
          end

          def sum(**args)
            virtual_parameters = args.dig(:virtual_definition)
            content = args.dig(:content)
            calculate(content, virtual_parameters.dig('virtual', 'data'), :sum)
          end

          def avg(**args)
            virtual_parameters = args.dig(:virtual_definition)
            content = args.dig(:content)
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
