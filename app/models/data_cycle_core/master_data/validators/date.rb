# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Date < BasicValidator
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

        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && data.blank?
        end
      end
    end
  end
end
