module DataCycleCore
  module MasterData
    module Validators
      class DateTime < BasicValidator
        # TODO: dummy evaluator for now
        def validate(data, template)
          if data.blank?
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warning], data: template['label'], locale: DataCycleCore.ui_language)
          end
          @error
        end
      end
    end
  end
end
