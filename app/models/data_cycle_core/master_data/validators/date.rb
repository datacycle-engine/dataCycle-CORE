# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for date values.
      #
      # Ensures that input can be parsed into a valid Date object and applies
      # optional validation rules such as required and minimum date constraints.
      class Date < BasicValidator
        # Validates date data against the provided template.
        #
        # Accepts blank values, strings (which are parsed), or Date-like objects.
        # Applies configured validations if present.
        #
        # @param data [String, Date, nil] Input value to validate
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          if data.blank?
            required(data, template['validations']['required']) if template.key?('validations') && template.dig('validations', 'required')
            # ignore
            return @error
          end

          value = data
          value = date(data) if data.is_a?(::String)

          unless value.acts_like?(:date)
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.date',
              substitutions: {
                data:
              }
            }

            return @error
          end

          if template.key?('validations')
            template['validations'].each_key do |key|
              validate_with_method(key, value, template['validations'][key])
            end
          end

          @error
        end

        # Attempts to parse a string into a Date.
        #
        # @param data [String] Input date string
        # @return [Date, nil] Parsed date or nil if invalid
        def date(data)
          data.to_date
        rescue StandardError
          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.date',
            substitutions: {
              data:
            }
          }
        end

        private

        # Validates that a date is not earlier than a minimum allowed value.
        #
        # @param data [Date] Input date
        # @param value [String, Date] Minimum allowed date
        # @return [void]
        def min(data, value)
          return unless data < value.to_date

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min_date',
            substitutions: {
              data:,
              min: value
            }
          }
        end

        # Validates required presence of a date value.
        #
        # @param data [Object] Input value
        # @param value [Boolean] Whether the field is required
        # @return [void]
        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && data.blank?
        end
      end
    end
  end
end
