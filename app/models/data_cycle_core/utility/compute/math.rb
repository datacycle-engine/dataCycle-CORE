# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Math
        class << self
          def sum(**args)
            args.dig(:computed_parameters).select { |v| v.is_a?(::Numeric) }.try(:sum)
          end
        end
      end
    end
  end
end
