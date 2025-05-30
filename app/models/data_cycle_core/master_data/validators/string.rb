# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class String < BasicValidator
        def string_formats
          ['uuid', 'url', 'soft_url', 'email', 'telephone_din5008']
        end

        def validate(data, template, _strict = false)
          if data.blank? || data.is_a?(::String)
            if template.key?('validations')
              template['validations'].each_key do |key|
                validate_with_method(key, data.to_s, template['validations'][key])
              end
            end
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

        def self.valid_url?(data)
          schemes = ['http', 'https', 'mailto', 'ftp', 'sftp', 'tel']
          schemes.include?(Addressable::URI.parse(data)&.scheme)
        rescue Addressable::URI::InvalidURIError
          false
        end

        private

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

        def min(data, value)
          min_for_type(data, value, :error)
        end

        def soft_min(data, value)
          min_for_type(data, value, :warning)
        end

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

        def max(data, value)
          max_for_type(data, value, :error)
        end

        def soft_max(data, value)
          max_for_type(data, value, :warning)
        end

        def pattern(data, expression)
          return if data.blank?
          regex = /#{expression[1..expression.length - 2]}/
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

        def url(data)
          return if data.blank? || self.class.valid_url?(data)

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.url',
            substitutions: {
              data:
            }
          }
        end

        def soft_url(data)
          return if data.blank? || self.class.valid_url?(data)

          (@error[:warning][@template_key] ||= []) << {
            path: 'validation.errors.url',
            substitutions: {
              data:
            }
          }
        end

        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && data.blank?
        end

        def soft_required(data, value)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.warnings.required' } if value && data.blank?
        end

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
