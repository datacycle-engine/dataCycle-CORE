# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Number < BasicValidator
        def number_keywords
          ['min', 'max', 'format']
        end

        def number_formats
          ['integer', 'float']
        end

        def validate(data, template, _strict = false)
          if data.is_a?(::Numeric)
            if template.key?('validations')
              template['validations'].each_key do |key|
                method(key).call(data, template['validations'][key]) if number_keywords.include?(key)
              end
            end
          elsif data.blank?
            # ignore
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.number',
              substitutions: {
                data: data,
                class: data.class,
                template: template['label']
              }
            }
          end
          @error
        end

        private

        # number validations
        def min(data, value)
          return unless data < value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min_number',
            substitutions: {
              data: data,
              value: value
            }
          }
        end

        def max(data, value)
          return unless data > value

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.max_number',
            substitutions: {
              data: data,
              value: value
            }
          }
        end

        def format(data, format_string)
          if number_formats.include?(format_string)
            method(format_string).call(data)
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.format',
              substitutions: {
                data: data,
                format_string: format_string
              }
            }
          end
        end

        # check number for given format
        def integer(data)
          return if data.is_a?(Integer)

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.integer',
            substitutions: {
              data: data
            }
          }
        end

        def float(data)
          return if data.to_f

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.float',
            substitutions: {
              data: data
            }
          }
        end
      end
    end
  end
end
