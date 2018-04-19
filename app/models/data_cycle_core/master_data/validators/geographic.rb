module DataCycleCore
  module MasterData
    module Validators
      class Geographic < BasicValidator
        # TODO: dummy evaluator for now
        def validate(data, template)
          if data.blank?
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warning], data: template['label'], locale: DataCycleCore.ui_language)
          elsif data.methods.include?(:geometry_type)
            # all ok
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:geo, scope: [:validation, :errors], data: data, template: template['label'], locale: DataCycleCore.ui_language)
          end
          @error
        end
      end
    end
  end
end
