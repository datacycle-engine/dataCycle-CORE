# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Geo
        class << self
          def coordinates_to_value(computed_parameters:, computed_definition:, **_args)
            return unless computed_definition['compute']&.key?('key') || computed_parameters.values.first.blank?

            DataCycleCore::MasterData::DataConverter.string_to_geographic(computed_parameters.values.first).try(computed_definition.dig('compute', 'key'))
          end

          def longitude_from_location(computed_parameters:, **_args)
            return if computed_parameters.values.first.blank? || computed_parameters.values.first&.longitude.blank?
            computed_parameters.values.first.longitude
          end

          def latitude_from_location(computed_parameters:, **_args)
            return if computed_parameters.values.first.blank? || computed_parameters.values.first&.latitude.blank?
            computed_parameters.values.first.latitude
          end
        end
      end
    end
  end
end
