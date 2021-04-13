# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Boolean
        class << self
          def default(property_definition:, **_additional_args)
            property_definition&.dig(:default_value, :value) || false
          end
        end
      end
    end
  end
end
