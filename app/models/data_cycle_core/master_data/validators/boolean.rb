# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for boolean values.
      #
      # Ensures that input is either a native boolean, a valid boolean string,
      # or blank. Invalid types or values are added as validation errors.
      class Boolean < BasicValidator
        # Validates boolean data against expected formats.
        #
        # Accepts TrueClass/FalseClass, boolean strings ("true"/"false"),
        # or blank values. Any other type is considered invalid.
        #
        # @param data [Boolean, String, nil] Input value to validate
        # @param _template [Hash] Validation template (unused)
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, _template, _strict = false)
          if data.is_a?(::TrueClass) || data.is_a?(::FalseClass)
            # all good
          elsif data.is_a?(::String)
            boolean(data)
          elsif data.blank?
            # ignore
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.date_time',
              substitutions: {
                data:
              }
            }
          end

          @error
        end

        # Validates boolean string representations.
        #
        # Accepts only "true" or "false" (after squishing whitespace).
        #
        # @param data [String] Input string value
        # @return [void]
        def boolean(data)
          return if ['true', 'false'].include?(data.squish)

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.boolean',
            substitutions: {
              data:
            }
          }
        end
      end
    end
  end
end
