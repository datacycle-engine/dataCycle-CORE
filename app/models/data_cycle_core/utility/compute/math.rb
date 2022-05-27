# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Math
        class << self
          def sum(computed_parameters:, **_args)
            computed_parameters.values.flatten.grep(::Numeric).sum
          end
        end
      end
    end
  end
end
