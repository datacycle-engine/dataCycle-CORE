module DataCycleCore
  module MasterData
    module Validators
      class Geographic < BasicValidator

        # TODO: dummy evaluator for now
        def validate(data, template)
          if data.blank?
            @error[:warning].push I18n.t :no_data, scope: [:validation, :warning], data: template['label']
          elsif data.methods.include?(:geometry_type)
            # all ok
          else
            @error[:error].push I18n.t :geo, scope: [:validation, :errors], data: data, template: template['label']
          end
          return @error
        end

      end
    end
  end
end
