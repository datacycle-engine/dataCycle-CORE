# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      # Validator class for string-based data types.
      #
      # Extends BasicValidator with string-specific validation rules such as
      # length constraints, formats, patterns, and content checks.
      class String < BasicValidator
        # Returns the list of supported string format validation methods.
        #
        # @return [Array<String>] Supported format validation identifiers
        def string_formats
          ['uuid', 'url', 'soft_url', 'email', 'telephone_din5008']
        end

        # Validates the given data against the provided template.
        #
        # Ensures the data is either blank or a String, then runs configured validations.
        # Adds an error if the data type is invalid.
        #
        # @param data [Object] The value to validate
        # @param template [Hash] Validation template containing rules and metadata
        # @param _strict [Boolean] Unused strict mode flag
        # @return [Hash] Collected validation errors and warnings
        def validate(data, template, _strict = false)
          if data.blank? || data.is_a?(::String)
            run_validations(data, template)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.string',
              substitutions: {
                template: data.class.name,
                label: template['label']
              }
            }
          end

          @error
        end

        # Validates whether a string is a valid UUID.
        #
        # Adds an error if the string does not match UUID format.
        #
        # @param data [String] The value to validate
        # @return [void]
        def uuid(data)
          data_uuid = data.downcase
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data.length == 36 && !(data_uuid =~ uuid).nil?

          return if check_uuid

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.uuid',
            substitutions: {
              data:
            }
          }
        end

        # Checks whether a string is a valid URL based on allowed schemes.
        #
        # @param data [String] The URL string to validate
        # @return [Boolean] True if the URL is valid, false otherwise
        def self.valid_url?(data)
          schemes = ['http', 'https', 'mailto', 'ftp', 'sftp', 'tel']
          schemes.include?(Addressable::URI.parse(data)&.scheme)
        rescue Addressable::URI::InvalidURIError
          false
        end

        private

        # Extends the list of validations that are allowed on blank values.
        #
        # @return [Array<String>] Combined list of validations allowed on blank data
        def validations_on_blank
          (super + ['min', 'soft_min', 'max', 'soft_max', 'soft_not_contains']).uniq
        end

        # Validates minimum length constraint and records result based on type.
        #
        # @param data [String] Input string
        # @param value [Integer] Minimum required length
        # @param type [Symbol] :error or :warning indicating severity
        # @return [void]
        def min_for_type(data, value, type = :error)
          text_length = ActionView::Base.full_sanitizer.sanitize(data).presence&.length.to_i

          return unless data.present? && text_length < value.to_i

          (@error[type][@template_key] ||= []) << {
            path: 'validation.errors.min',
            substitutions: {
              data: nil,
              min: value.to_i,
              length: text_length
            }
          }
        end

        # Enforces minimum length as an error.
        #
        # @param data [String] Input string
        # @param value [Integer] Minimum length
        # @return [void]
        def min(data, value)
          min_for_type(data, value, :error)
        end

        # Enforces minimum length as a warning.
        #
        # @param data [String] Input string
        # @param value [Integer] Minimum length
        # @return [void]
        def soft_min(data, value)
          min_for_type(data, value, :warning)
        end

        # Validates maximum length constraint and records result based on type.
        #
        # @param data [String] Input string
        # @param value [Integer] Maximum allowed length
        # @param type [Symbol] :error or :warning indicating severity
        # @return [void]
        def max_for_type(data, value, type = :error)
          text_length = ActionView::Base.full_sanitizer.sanitize(data).presence&.length.to_i

          return unless data.present? && text_length.to_i > value.to_i

          (@error[type][@template_key] ||= []) << {
            path: 'validation.errors.max',
            substitutions: {
              data: nil,
              max: value.to_i,
              length: text_length
            }
          }
        end

        # Enforces maximum length as an error.
        #
        # @param data [String] Input string
        # @param value [Integer] Maximum length
        # @return [void]
        def max(data, value)
          max_for_type(data, value, :error)
        end

        # Enforces maximum length as a warning.
        #
        # @param data [String] Input string
        # @param value [Integer] Maximum length
        # @return [void]
        def soft_max(data, value)
          max_for_type(data, value, :warning)
        end

        # Validates that the entire string matches a given regex pattern.
        #
        # @param data [String] Input string
        # @param expression [String] Regex expression string (with delimiters)
        # @return [void]
        def pattern(data, expression)
          return if data.blank?

          regex = /#{expression[1..-2]}/
          matched = data.match(regex)

          return unless matched.nil? || matched.offset(0) != [0, data.size]

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.match',
            substitutions: {
              data:,
              expression:
            }
          }
        end

        # Adds a warning if the string contains a forbidden substring.
        #
        # @param data [String] Input string
        # @param expression [String] Substring that should not be present
        # @return [void]
        def soft_not_contains(data, expression)
          return unless data&.include?(expression)

          (@error[:warning][@template_key] ||= []) << {
            path: 'validation.errors.not_contains',
            substitutions: {
              data:,
              expression:
            }
          }
        end

        # Executes a format validation based on the provided format identifier.
        #
        # @param data [String] Input string
        # @param format_string [String] Format identifier
        # @return [void]
        #
        def format(data, format_string)
          if string_formats.include?(format_string)
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

        # Validates that the string is a valid URL (error level).
        #
        # @param data [String] Input string
        # @return [void]
        def url(data)
          return if data.blank? || self.class.valid_url?(data)

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.url',
            substitutions: {
              data:
            }
          }
        end

        # Validates that the string is a valid URL (warning level).
        #
        # @param data [String] Input string
        # @return [void]
        def soft_url(data)
          return if data.blank? || self.class.valid_url?(data)

          (@error[:warning][@template_key] ||= []) << {
            path: 'validation.errors.url',
            substitutions: {
              data:
            }
          }
        end

        # Validates a telephone number according to DIN 5008 formatting rules.
        #
        # Adds a warning if the number does not comply with the format.
        #
        # @param data [String] Telephone number string
        # @return [void]
        def telephone_din5008(data)
          din5008 = /^(\+[1-9]\d+) ([1-9]\d*) ([1-9]\d+)(-\d+){0,1}$|^(0\d+) ([1-9]\d+)(-\d+){0,1}$|^([1-9]\d+)(-\d+){0,1}$|^(\+[1-9]\d+) ([1-9]\d+)(-\d+){0,1}$/
          check_telephone = !(data =~ din5008).nil?

          return if check_telephone

          (@error[:warning][@template_key] ||= []) << {
            path: 'validation.warnings.telephone_din5008',
            substitutions: {
              data:
            }
          }
        end
      end
    end
  end
end
