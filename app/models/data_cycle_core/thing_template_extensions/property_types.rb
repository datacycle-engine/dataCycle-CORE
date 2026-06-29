# frozen_string_literal: true

module DataCycleCore
  module ThingTemplateExtensions
    # Property-type helpers for template schema inspection.
    module PropertyTypes
      GEO_PROPERTY_TYPES = ['geographic'].freeze

      # Returns the property definition for a nested property path.
      #
      # @param property_path [String, Symbol, Array<String, Symbol>] Property key or key path.
      # @param _include_overlay [Boolean] Reserved parameter for interface compatibility.
      # @return [Hash, nil] Property definition for the given path.
      def properties_for(property_path, _include_overlay = false) # rubocop:disable Style/OptionalBooleanParameter
        return if property_path.blank?

        definitions = property_definitions
        full_path = Array.wrap(property_path).map(&:to_s).intersperse('properties')

        definitions.dig(*full_path)
      end

      # Selects all geographic property definitions from the template.
      #
      # @param _include_overlay [Boolean] Reserved parameter for interface compatibility.
      # @return [Hash{String => Hash}] Geographic property definitions keyed by property name.
      def geo_properties(_include_overlay = false) # rubocop:disable Style/OptionalBooleanParameter
        property_selector { |definition| GEO_PROPERTY_TYPES.include?(definition['type']) }
      end

      # Returns all geographic property names from the template.
      #
      # @param _include_overlay [Boolean] Reserved parameter for interface compatibility.
      # @return [Array<String>] Geographic property names.
      def geo_property_names(_include_overlay = false) # rubocop:disable Style/OptionalBooleanParameter
        name_property_selector { |definition| GEO_PROPERTY_TYPES.include?(definition['type']) }
      end

      private

      def name_property_selector(&)
        property_selector(&).keys
      end

      def property_selector
        property_definitions.select { |_, definition| yield(definition) }
      end
    end
  end
end
