# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Common
        class << self
          def copy(**args)
            args[:computed_parameters]&.first
          end
        end
      end
    end
  end
end
