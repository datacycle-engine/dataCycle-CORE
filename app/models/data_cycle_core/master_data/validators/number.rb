# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for numeric data types.
      #
      # Provides validation for numeric values including type checking,
      # range constraints, and format enforcement (e.g., integer, float).
      class Number < BasicValidator
        # Returns supported number format validation methods.
        #
        # @return [Array<String>] Supported format identifiers
        def number_formats
          ['integer', 'float']
        end

        # Validates numeric data against the provided template.
        #
        # Ensures the data is of a valid numeric type, then applies configured validations.
        #
        # @param data [Numeric, nil] Value to validate
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          return type_error(data, template) unless valid_type?(data)

          run_validations(data, template)
          @error
        end

        private

        # Checks whether the provided data is a valid numeric type or blank.
        #
        # @param data [Object] Input value
        # @return [Boolean] True if numeric or blank, false otherwise
        def valid_type?(data)
          data.is_a?(::Numeric) || data.blank?
        end

        # Adds an error for invalid numeric types.
        #
        # @param data [Object] Invalid input value
        # @param template [Hash] Validation template
        # @return [Hash] Updated error hash
        def type_error(data, template)
          add_error(
            'validation.errors.number',
            data: data,
            class: data.class,
            template: template['label']
          )
          @error
        end

        # Validates that a number is not less than a minimum value.
        #
        # @param data [Numeric] Input number
        # @param value [Numeric] Minimum allowed value
        # @return [void]
        def min(data, value)
          return unless data < value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min_number',
            substitutions: {
              data:,
              value:
            }
          }
        end

        # Validates that a number does not exceed a maximum value.
        #
        # @param data [Numeric] Input number
        # @param value [Numeric] Maximum allowed value
        # @return [void]
        def max(data, value)
          return unless data > value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.max_number',
            substitutions: {
              data:,
              value:
            }
          }
        end

        # Executes a format validation based on the provided format identifier.
        #
        # @param data [Numeric] Input number
        # @param format_string [String] Format identifier
        # @return [void]
        def format(data, format_string)
          if number_formats.include?(format_string)
            method(format_string).call(data)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.format',
              substitutions: {
                data:,
                format_string:
              }
            }
          end
        end

        # Validates that the number is an integer.
        #
        # @param data [Numeric] Input number
        # @return [void]
        def integer(data)
          return if data.is_a?(Integer)

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.integer',
            substitutions: {
              data:
            }
          }
        end

        # Validates that the number is a float (numeric).
        #
        # @param data [Numeric] Input number
        # @return [void]
        def float(data)
          return if data.is_a?(::Numeric)

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.float',
            substitutions: {
              data:
            }
          }
        end
      end
    end
  end
end
