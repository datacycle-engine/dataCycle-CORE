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
            # (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warnings], data: template['label'], locale: DataCycleCore.ui_locales.first)
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:date_time, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_locales.first)
          end
          @error
        end

        def boolean(data)
          (@error[:error][@template_key] ||= []) << I18n.t(:boolean, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_locales.first) unless data.squish == 'true' || data.squish == 'false'
        end
      end
    end
  end
end
