# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for geographic data.
      #
      # Supports validation of WKT (Well-Known Text) strings and RGeo objects.
      # Ensures geometries are parseable and structurally valid.
      class Geographic < BasicValidator
        # Validates geographic data against the provided template.
        #
        # Accepts blank values, WKT strings, or RGeo geometry objects.
        # Applies configured validations if the type is valid.
        #
        # @param data [String, Object, nil] Geographic data (WKT or RGeo object)
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          return type_error(data, template) unless valid_type?(data)

          run_validations(data, template)
          @error
        end

        private

        # Checks whether the provided data is a valid geographic type.
        #
        # @param data [Object] Input value
        # @return [Boolean] True if valid, false otherwise
        def valid_type?(data)
          return true if data.blank?
          return valid_wkt?(data) if data.is_a?(::String)
          return true if rgeo_object?(data)

          false
        end

        # Validates whether a string is a valid WKT representation.
        #
        # Attempts parsing with both 2D and 3D configurations.
        #
        # @param data [String] WKT string
        # @return [Boolean] True if valid, false otherwise
        def valid_wkt?(data)
          convert_2d = parse_wkt(data, has_z: false)
          convert_3d = parse_wkt(data, has_z: true)

          return false if convert_2d == :invalid_geometry || convert_3d == :invalid_geometry

          if convert_2d == :parse_error && convert_3d == :parse_error
            add_error('validation.errors.geo', data: data, template: @template_label)
            false
          end

          true
        end

        # Attempts to parse a WKT string using an RGeo factory.
        #
        # @param data [String] WKT string
        # @param has_z [Boolean] Whether to use a 3D parser
        # @return [Object, Symbol] Parsed geometry or error indicator
        def parse_wkt(data, has_z:)
          factory(has_z:).parse_wkt(data)
        rescue RGeo::Error::InvalidGeometry
          add_error('validation.errors.geo_no_linestring')
          :invalid_geometry
        rescue RGeo::Error::ParseError
          :parse_error
        end

        # Returns or builds an RGeo factory instance.
        #
        # @param has_z [Boolean] Whether the factory supports Z coordinates
        # @return [RGeo::Geographic::Factory] Configured RGeo factory
        def factory(has_z:)
          @factories ||= {}
          @factories[has_z] ||= RGeo::Geographic.simple_mercator_factory(
            uses_lenient_assertions: true,
            srid: 4326,
            has_z_coordinate: has_z,
            wkt_parser: { support_wkt12: true },
            wkt_generator: { convert_case: :upper, tag_format: :wkt12 }
          )
        end

        # Checks whether the given object is an RGeo geometry.
        #
        # @param data [Object] Input value
        # @return [Boolean] True if it responds to geometry_type, false otherwise
        def rgeo_object?(data)
          data.respond_to?(:geometry_type)
        end

        # Adds an error for invalid geographic data type.
        #
        # @param data [Object] Invalid input value
        # @param template [Hash] Validation template
        # @return [Hash] Updated error hash
        def type_error(data, template)
          add_error(
            'validation.errors.geo',
            data: data,
            template: template['label']
          )
          @error
        end
      end
    end
  end
end
