# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Manages content serialization formats and their availability.
    #
    # Serialize controls which serialization formats (JSON, XML, asset, etc.) are enabled
    # and available for content export. It handles conditional enablement based on feature
    # dependencies and configuration. Serializers can be custom classes or default implementations
    # in the DataCycleCore::Serialize::Serializer namespace.
    #
    # @example Get available serializers for content
    #   Serialize.available_serializers(content) #=> { 'json' => true, 'xml' => {...} }
    #
    # @example Check if a specific serializer is enabled
    #   Serialize.enabled_serializer?(['json', 'xml']) #=> true
    #
    # @example Get the serializer class for a format
    #   Serialize.serializer_for_content('json') #=> DataCycleCore::Serialize::Serializer::Json
    class Serialize < Base
      class << self
        def available_serializers(content = nil)
          configuration(content)['serializers'].select { |k, _| enabled_serializers[k] }
        end

        def available_serializer?(content, serializer)
          available_serializers(content)[serializer].present?
        end

        def enabled_serializers
          configuration['serializers'].reject do |_, value|
            value.blank? ||
              (
                value.is_a?(::Hash) && value['depends_on'].present? &&
                Array.wrap(value['depends_on']).none? { |dep| dependency_enabled?(dep) }
              )
          end
        end

        def enabled_serializer?(serializers)
          serializers&.each do |format|
            return true if enabled_serializers[format]
          end

          false
        end

        def asset_versions(content = nil)
          configuration(content).dig('serializers', 'asset').is_a?(Hash) ? configuration(content).dig('serializers', 'asset') : {}
        end

        def serializer_for_content(serialize_format)
          serializer_name = enabled_serializers[serialize_format.to_s]

          return "DataCycleCore::Serialize::Serializer::#{serialize_format.to_s.classify}".constantize if serializer_name.is_a?(TrueClass) || (serializer_name.is_a?(::Hash) && serializer_name['class'].blank?)

          return serializer_name.to_s.safe_constantize if serializer_name.is_a?(::String) || serializer_name.is_a?(::Symbol)

          return serializer_name['class'].to_s.safe_constantize if serializer_name.is_a?(::Hash) && serializer_name['class'].present?

          nil
        end

        private

        def serializer_enabled?(serialize_format)
          enabled_serializers[serialize_format.to_s].present?
        end

        def dependency_enabled?(dependency)
          return false unless dependency.is_a?(::Hash) &&
                              dependency.key?('module') && dependency['module'].is_a?(::String) &&
                              dependency.key?('method') && dependency['method'].is_a?(::String)

          dependency['module']&.safe_constantize&.try(dependency['method']) || false
        end
      end
    end
  end
end
