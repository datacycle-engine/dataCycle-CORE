# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Datetime < BasicValidator
        def datetime_keywords
          ['min']
        end

        def validate(data, template)
          if data.blank?
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warning], data: template['label'], locale: DataCycleCore.ui_language)
            return @error
          end

          value = data
          value = datetime(data) if data.is_a?(::String)
          unless value.acts_like?(:time)
            (@error[:error][@template_key] ||= []) << I18n.t(:date_time, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language)
            return @error
          end

          if template.key?('validations')
            template['validations'].each_key do |key|
              if datetime_keywords.include?(key)
                method(key).call(value, template['validations'][key])
              else
                (@error[:warning][@template_key] ||= []) << I18n.t(:string, scope: [:validation, :warnings], data: data, key: key, template: template, locale: DataCycleCore.ui_language) unless key == 'type'
              end
            end
          end
          @error
        end

        def datetime(data)
          data.in_time_zone
        rescue StandardError
          (@error[:error][@template_key] ||= []) << I18n.t(:date_time, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language)
        end

        private

        def min(data, value)
          (@error[:error][@template_key] ||= []) << I18n.t(:min_datetime, scope: [:validation, :errors], data: data, min: value, locale: DataCycleCore.ui_language) if data < value.to_datetime
        end
      end
    end
  end
end
