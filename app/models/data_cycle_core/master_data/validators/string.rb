# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class String < BasicValidator
        def string_keywords
          ['min', 'max', 'format', 'pattern', 'required', 'soft_required']
        end

        def string_formats
          ['uuid', 'url', 'soft_url', 'email', 'telephone_din5008']
        end

        def validate(data, template, _strict = false)
          if data.blank? || data.is_a?(::String)
            if template.key?('validations')
              template['validations'].each_key do |key|
                method(key).call(data.to_s, template['validations'][key]) if string_keywords.include?(key)
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

        def min(data, value)
          text_length = ActionView::Base.full_sanitizer.sanitize(data).presence&.length.to_i

          return unless data.present? && text_length < value.to_i

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min',
            substitutions: {
              data: nil,
              min: value.to_i,
              length: text_length
            }
          }
        end

        def max(data, value)
          text_length = ActionView::Base.full_sanitizer.sanitize(data).presence&.length.to_i

          return unless data.present? && text_length.to_i > value.to_i

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.max',
            substitutions: {
              data: nil,
              max: value.to_i,
              length: text_length
            }
          }
        end

        def pattern(data, expression)
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
          din5008 = /^(\+[1-9]\d+) ([1-9]\d*) ([1-9]\d+)(\-\d+){0,1}$|^(0\d+) ([1-9]\d+)(\-\d+){0,1}$|^([1-9]\d+)(\-\d+){0,1}$|^(\+[1-9]\d+) ([1-9]\d+)(\-\d+){0,1}$/
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
