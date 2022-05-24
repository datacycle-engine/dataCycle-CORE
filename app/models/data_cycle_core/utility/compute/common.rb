# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Common
        class << self
          def copy(computed_parameters:, **_args)
            computed_parameters.values.first
          end
        end
      end
    end
  end
end
