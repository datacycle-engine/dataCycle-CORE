# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Date < BasicValidator
        def date_keywords
          ['min']
        end

        def validate(data, template, _strict = false)
          if data.blank?
            # (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warnings], data: template['label'], locale: DataCycleCore.ui_locales.first)
            return @error
          end

          value = data
          value = date(data) if data.is_a?(::String)
          unless value.acts_like?(:date)
            (@error[:error][@template_key] ||= []) << I18n.t(:date, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_locales.first)
            return @error
          end

          if template.key?('validations')
            template['validations'].each_key do |key|
              method(key).call(value, template['validations'][key]) if date_keywords.include?(key)
            end
          end
          @error
        end

        def date(data)
          data.to_date
        rescue StandardError
          (@error[:error][@template_key] ||= []) << I18n.t(:date, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_locales.first)
        end

        private

        def min(data, value)
          (@error[:error][@template_key] ||= []) << I18n.t(:min_date, scope: [:validation, :errors], data: data, min: value, locale: DataCycleCore.ui_locales.first) if data < value.to_date
        end
      end
    end
  end
end
