# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Key < BasicValidator
        def validate(data, template, _strict = false)
          @template_key = template['label']
          if data.is_a?(::String)
            uuid?(data)
          elsif data.blank?
            # ignore
          else
            (@error[:error][@template_key] ||= []) << {
              path: 'validation.errors.key',
              substitutions: {
                data:
              }
            }
          end

          @error
        end
      end
    end
  end
end
