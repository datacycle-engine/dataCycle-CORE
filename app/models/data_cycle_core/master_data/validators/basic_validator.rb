# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Base validator class providing shared validation utilities and execution
      # flow for master data validation rules.
      #
      # This class is intended to be subclassed with specific validation methods
      # implemented as private methods.
      class BasicValidator
        attr_reader :error

        VALIDATIONS_ON_BLANK = ['required', 'soft_required', 'conditional_required'].freeze

        # Initializes the validator and immediately runs validation.
        #
        # @param data [Object] The input data to validate
        # @param template [Hash] Validation template containing rules and configuration
        # @param template_key [String] Key used for error grouping and reporting
        # @param strict [Boolean] Whether strict validation mode is enabled
        # @param content [Object, nil] Optional additional content used in validation
        def initialize(data, template, template_key = '', strict = false, content = nil)
          @content = content
          @error = { error: {}, warning: {} }
          @template_key = template_key
          validate(data, template, strict)
        end

        # Main validation entry point (intended to be overridden in subclasses).
        #
        # @param data [Object] The input data to validate
        # @param template [Hash] Validation template containing rules
        # @param strict [Boolean] Whether strict validation mode is enabled
        # @return [void]
        def validate(data, template, strict = false)
        end

        # Merges external error hashes into the internal error store.
        #
        # @param error_hash [Hash] Hash containing :error and/or :warning entries
        # @return [void]
        def merge_errors(error_hash)
          @error.each_key do |key|
            @error[key].merge!(error_hash[key]) if error_hash.key?(key)
          end
        end

        # Validates whether a given value is a valid UUID (RFC 4122 format).
        #
        # Adds an error entry if the value is not a valid UUID.
        #
        # @param data [String] The value to validate as UUID
        # @return [Boolean] True if valid UUID, false otherwise
        def uuid?(data)
          data_clean = data.squish.downcase
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data_clean.length == 36 && !(data_clean =~ uuid).nil?
          unless check_uuid
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.uuid',
              substitutions: {
                data:
              }
            }
          end

          check_uuid
        end

        # Returns validation keys that can be executed even when data is blank.
        #
        # @return [Array<String>] List of validation names allowed on blank data
        def validations_on_blank
          VALIDATIONS_ON_BLANK
        end

        # Executes validation rules defined in the template.
        #
        # Splits validations into those allowed on blank values and those that
        # require presence, then executes them in order.
        #
        # @param data [Object] The input data being validated
        # @param template [Hash] Validation template containing rules
        # @return [void]
        def run_validations(data, template)
          return unless template.key?('validations')

          blank, present = split_validations(template['validations'])

          execute_validations(blank, data, template, true)
          return if errors_present?

          execute_validations(present, data, template, false)
        end

        private

        # Splits validations into those allowed on blank data and those that are not.
        #
        # @param validations [Hash] Validation definitions from template
        # @return [Array<Hash>] Two hashes: [blank_validations, present_validations]
        def split_validations(validations)
          blank_validations, present_validations = validations.partition { |key, _value| validations_on_blank.include?(key) }

          [blank_validations.to_h, present_validations.to_h]
        end

        # Checks whether any errors or warnings have been recorded.
        #
        # @return [Boolean] True if errors or warnings exist, false otherwise
        def errors_present?
          @error[:error].present? || @error[:warning].present?
        end

        # Executes a set of validation methods defined in the validation hash.
        #
        # @param validations [Hash] Validation rules to execute
        # @param data [Object] Input data being validated
        # @param template [Hash] Full validation template
        # @param allow_blank [Boolean] Whether blank data is allowed
        # @return [void]
        def execute_validations(validations, data, template, allow_blank = false)
          return if data.blank? && !allow_blank

          validations.each_key do |key|
            validate_with_method(key, data, template['validations'][key])
          end
        end

        # Dynamically calls a validation method if it exists and matches expected signature.
        #
        # @param key [Symbol, String] Validation method name
        # @param data [Object] Input data
        # @param value [Object] Validation configuration value
        # @return [void]
        def validate_with_method(key, data, value)
          return unless self.class.private_method_defined?(key)

          m = method(key)
          return unless m.parameters.size == 2

          m.call(data, value)
        end

        # Checks whether a value is considered blank using DataHashService rules.
        #
        # @param data [Object] The value to check
        # @return [Boolean] True if blank, false otherwise
        def blank?(data)
          DataCycleCore::DataHashService.blank?(data)
        end

        # Adds an error if a required field is blank.
        #
        # @param data [Object] Input value
        # @param value [Boolean] Whether the field is marked as required
        # @return [void]
        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && blank?(data)
        end

        # Adds a warning if a soft-required field is blank.
        #
        # @param data [Object] Input value
        # @param value [Boolean] Whether the field is marked as soft required
        # @return [void]
        def soft_required(data, value)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.warnings.required' } if value && blank?(data)
        end

        # Adds a error if a conditional-required field is blank while the condition is met (e.g., another field has a specific value).
        # @note This method is currently a placeholder and only works on the frontend.
        #
        # @param data [Object] Input value
        # @param value [Boolean] Whether the field is marked as conditional required
        # @return [void]
        def conditional_required(data, value)
          # (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && blank?(data)
        end

        # Adds a custom validation error entry.
        #
        # @param path [String] Error message key/path
        # @param substitutions [Hash] Optional interpolation values for error messages
        # @return [void]
        def add_error(path, substitutions = {})
          (@error[:error][@template_key] ||= []) << {
            path: path,
            substitutions: substitutions
          }
        end

        # Adds a custom validation warning entry.
        #
        # @param path [String] Warning message key/path
        # @param substitutions [Hash] Optional interpolation values for warning messages
        # @return [void]
        def add_warning(path, substitutions = {})
          (@error[:warning][@template_key] ||= []) << {
            path: path,
            substitutions: substitutions
          }
        end
      end
    end
  end
end
