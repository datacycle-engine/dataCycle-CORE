# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Common
        class << self
          def copy(computed_parameters:, key:, data_hash:, content:)
            computed_parameters.first.value
          end
        end
      end
    end
  end
end
