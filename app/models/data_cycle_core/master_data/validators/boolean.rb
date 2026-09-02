# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for boolean values.
      #
      # Whatever DataConverter.string_to_boolean converts is valid; anything else
      # is added as a validation error.
      class Boolean < BasicValidator
        # Validates boolean data against expected formats.
        #
        # @param data [Boolean, String, nil] Input value to validate
        # @param _template [Hash] Validation template (unused)
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, _template, _strict = false)
          begin
            DataCycleCore::MasterData::DataConverter.string_to_boolean(data)
          rescue ArgumentError
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.boolean',
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
