# frozen_string_literal: true

module DataCycleCore
  module Feature
    class GeoKeyFigure < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::GeoKeyFigure
        end

        def local(content)
          configuration(content)['local']
        end

        def allowed_child_attribute_key?(content, definition)
          definition&.[]('properties')&.keys&.any? { |key| allowed_attribute_key?(content, key) }
        end

        def external_source
          @external_source ||= DataCycleCore::ExternalSystem.find_by(name: configuration[:external_source])
        end

        def endpoint
          @endpoint ||= (configuration[:endpoint].constantize.new(**external_source.credentials.symbolize_keys) if external_source.present?)
        end

        def get_key_figure(part_ids, key = nil)
          return {} if endpoint.blank? || part_ids.blank? || key.nil?

          endpoint.get_key_figure(part_ids, key)
        end
      end
    end
  end
end
