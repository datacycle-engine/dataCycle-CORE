# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Datetime < BasicValidator
        def datetime_keywords
          ['min']
        end

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
                data: data
              }
            }

            return @error
          end

          if template.key?('validations')
            template['validations'].each_key do |key|
              method(key).call(value, template['validations'][key]) if datetime_keywords.include?(key)
            end
          end
          @error
        end

        def datetime(data)
          data.in_time_zone
        rescue StandardError
          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.date_time',
            substitutions: {
              data: data
            }
          }
        end

        private

        def min(data, value)
          return unless data < value.to_datetime

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.min_datetime',
            substitutions: {
              data: data,
              min: value
            }
          }
        end
      end
    end
  end
end
