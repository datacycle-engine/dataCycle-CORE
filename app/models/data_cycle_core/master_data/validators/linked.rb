module DataCycleCore
  module MasterData
    module Validators
      class Linked < Embedded
        def validate_reference(key, template)
          if key.is_a?(::String)
            check_reference(key, template)
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:data_format, scope: [:validation, :errors], key: key, template: template['label'], locale: DataCycleCore.ui_language)
          end
        end
      end
    end
  end
end
