module DataCycleCore
  module MasterData
    module Validators
      class Datetime < BasicValidator
        def validate(data, template)
          @template_key = template['label']
          if data.is_a?(::Time) || data.is_a?(::Date)
            # all good
          elsif data.is_a?(::String)
            datetime(data)
          elsif data.blank?
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warning], data: template['label'], locale: DataCycleCore.ui_language)
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:date_time, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language)
          end
          @error
        end

        def datetime(data)
          data.to_datetime
        rescue StandardError
          (@error[:error][@template_key] ||= []) << I18n.t(:date_time, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language)
        end
      end
    end
  end
end
