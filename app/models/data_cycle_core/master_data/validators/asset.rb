# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for asset references.
      #
      # Ensures that provided asset identifiers or objects are valid UUIDs,
      # exist in the database, and match the expected asset type defined in the template.
      class Asset < BasicValidator
        # Validates asset data against the provided template.
        #
        # Accepts arrays of UUID strings, Asset objects, or blank values.
        # Normalizes input and validates both structure and referenced assets.
        #
        # @param data [Array<String, DataCycleCore::Asset>, String, nil] Asset references
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          check_reference_array(Array(data), template)

          @error
        end

        private

        # Validates an array of asset references.
        #
        # Applies configured validations and checks each reference for validity.
        #
        # @param data [Array<Object>] Asset references
        # @param template [Hash] Validation template
        # @return [void]
        def check_reference_array(data, template)
          run_validations(data, template)

          return if blank?(data)

          data.each do |key|
            if key.is_a?(::String)
              check_reference(key, template)
            elsif key.is_a?(DataCycleCore::Asset)
              check_reference(key.id, template)
            else
              (@error[:error][@template_key] ||= []) << {
                path: 'validation.errors.data_array_format',
                substitutions: {
                  key:,
                  template: template['label']
                }
              }
            end
          end
        end

        # Validates a single asset reference by UUID and type.
        #
        # Loads the asset and checks whether its type matches the expected template type.
        #
        # @param key [String] Asset UUID
        # @param template [Hash] Validation template
        # @return [void]
        def check_reference(key, template)
          return unless uuid?(key)

          find_asset = DataCycleCore::Asset.find(key)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.errors.asset_upload' } if !check_asset_type(find_asset, template) || find_asset.nil?
        end

        # Checks whether an asset matches the expected type defined in the template.
        #
        # @param asset [DataCycleCore::Asset] Asset record
        # @param template [Hash] Validation template
        # @return [Boolean] True if asset type matches, false otherwise
        def check_asset_type(asset, template) # rubocop:disable Naming/PredicateMethod
          asset.type == "DataCycleCore::#{template['asset_type'].camelize}"
        end

        # Validates that required asset data is present.
        #
        # @param data [Object] Input value
        # @param value [Boolean] Whether the field is required
        # @return [void]
        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && blank?(data)
        end
      end
    end
  end
end
