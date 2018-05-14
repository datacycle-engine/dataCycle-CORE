module DataCycleCore
  module MasterData
    module Validators
      class Datetime < BasicValidator
        def datetime_keywords
          ['min']
        end

        def validate(data, template)
          if data.is_a?(::Time) || data.is_a?(::Date)
            # all good
          elsif data.is_a?(::String)
            if template.key?('validations')
              template['validations'].each_key do |key|
                if datetime_keywords.include?(key)
                  method(key).call(data, template['validations'][key])
                else
                  (@error[:warning][@template_key] ||= []) << I18n.t(:string, scope: [:validation, :warnings], data: data, key: key, template: template, locale: DataCycleCore.ui_language) unless key == 'type'
                end
              end
            end
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

        private

        def min(data, value)
          (@error[:error][@template_key] ||= []) << I18n.t(:min, scope: [:validation, :errors], data: data, min: value.to_i, length: data.length, locale: DataCycleCore.ui_language) if data.length < value.to_i
        end
      end
    end
  end
end
