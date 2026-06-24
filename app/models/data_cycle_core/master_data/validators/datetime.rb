# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator for datetime values.
      #
      # Ensures that the provided data can be parsed into a valid time object
      # and applies optional validation rules such as minimum datetime constraints.
      class Datetime < BasicValidator
        # Validates datetime data against the provided template.
        #
        # Accepts blank values or values that can be converted into a time-like object.
        # Applies configured validations if present in the template.
        #
        # @param data [String, Time, DateTime, nil] Input value to validate
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          if data.blank?
            # ignore
            return @error
          end

          value = data
          value = datetime(data) if data.is_a?(::String)

          unless value.acts_like?(:time)
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.date_time',
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

        # Attempts to convert a value into a time object.
        #
        # @param data [String] Input datetime string
        # @return [ActiveSupport::TimeWithZone, nil] Parsed datetime or nil if invalid
        def datetime(data)
          data.in_time_zone
        rescue StandardError
          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.date_time',
            substitutions: {
              data:
            }
          }
        end

        private

        # Validates that a datetime is not earlier than a minimum value.
        #
        # @param data [Time, DateTime] Input datetime
        # @param value [String, DateTime] Minimum allowed datetime
        # @return [void]
        def min(data, value)
          return unless data < value.to_datetime

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min_datetime',
            substitutions: {
              data:,
              min: value
            }
          }
        end
      end
    end
  end
end
