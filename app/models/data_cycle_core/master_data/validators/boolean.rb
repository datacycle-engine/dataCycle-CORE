module DataCycleCore
  module MasterData
    module Validators
      class Boolean < BasicValidator
        def validate(data, template)
          @template_key = template['label']
          if data.is_a?(TrueClass) || data.is_a?(FalseClass)
            # all good
          elsif data.is_a?(String)
            boolean(data)
          elsif data.blank?
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warning], data: template['label'], locale: DataCycleCore.ui_language)
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:date_time, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language)
          end
          @error
        end

        def boolean(data)
          (@error[:error][@template_key] ||= []) << I18n.t(:boolean, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language) unless data.squish == 'true' || data.squish == 'false'
        end
      end
    end
  end
end
