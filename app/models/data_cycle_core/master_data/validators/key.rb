# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for key-type values.
      #
      # Ensures that the provided data is either a valid UUID string or blank.
      # Adds an error if the value is not a string or does not match UUID format.
      class Key < BasicValidator
        # Validates key data against the provided template.
        #
        # Accepts string values (validated as UUIDs) or blank values.
        # Adds an error if the data type is invalid.
        #
        # @param data [String, nil] Value to validate
        # @param template [Hash] Validation template containing metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          @template_key = template['label']

          if data.is_a?(::String)
            uuid?(data)
          elsif data.blank?
            # ignore
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.key',
              substitutions: {
                data:
              }
            }
          end

          @error
        end
      end
    end
  end
end
