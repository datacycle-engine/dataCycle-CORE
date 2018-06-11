# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Key < BasicValidator
        def validate(data, template)
          @template_key = template['label']
          if data.is_a?(::String)
            uuid?(data)
          elsif data.blank?
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warning], data: template['label'], locale: DataCycleCore.ui_language)
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:key, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language)
          end
          @error
        end
      end
    end
  end
end
