# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Geo
        class << self
          def coordinates_to_value(computed_parameters:, computed_definition:, **_args)
            return unless computed_definition.dig('compute')&.key?('key') || computed_parameters.values.first.blank?

            DataCycleCore::MasterData::DataConverter.string_to_geographic(computed_parameters.values.first).try(computed_definition.dig('compute', 'key'))
          end
        end
      end
    end
  end
end
