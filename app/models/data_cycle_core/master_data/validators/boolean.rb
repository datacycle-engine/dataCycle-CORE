# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Boolean < BasicValidator
        def validate(data, template, _strict = false)
          @template_key = template['label']
          if data.is_a?(::TrueClass) || data.is_a?(::FalseClass)
            # all good
          elsif data.is_a?(::String)
            boolean(data)
          elsif data.blank?
            # ignore
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.date_time',
              substitutions: {
                data:
              }
            }
          end

          @error
        end

        def boolean(data)
          return if data.squish == 'true' || data.squish == 'false'

          (@error[:error][@template_key] ||= []) << {
            path: 'validation.errors.boolean',
            substitutions: {
              data:
            }
          }
        end
      end
    end
  end
end
