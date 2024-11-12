# frozen_string_literal: true

module DataCycleCore
  module Feature
    class GeoAddElevation < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::GeoAddElevation
        end

        def routes_module
          DataCycleCore::Feature::Routes::GeoAddElevation
        end

        def external_source
          @external_source ||= DataCycleCore::ExternalSystem.find_by(name: configuration[:external_source])
        end

        def endpoint
          @endpoint ||= (configuration[:endpoint].constantize.new(**external_source.credentials.symbolize_keys) if external_source.present?)
        end

        def add_elevation_values(value)
          return {} if endpoint.blank? || value.blank?

          endpoint.add_elevation_values(value)
        end
      end
    end
  end
end
