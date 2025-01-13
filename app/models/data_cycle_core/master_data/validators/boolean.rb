# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Boolean < BasicValidator
        def validate(data, _template, _strict = false)
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
          return if ['true', 'false'].include?(data.squish)

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
