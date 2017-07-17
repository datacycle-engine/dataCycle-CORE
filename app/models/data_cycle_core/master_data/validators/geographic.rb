module DataCycleCore
  module MasterData
    module Validators
      class Geographic < BasicValidator

        # TODO: dummy evaluator for now
        def validate(data, template)
          if data.blank?
            @error[:warning].push I18n.t :no_data, scope: [:validation, :warning], data: template['label']
            #@error[:warning].push "No data given for #{template['label']}."
          elsif data.methods.include?(:geometry_type)
            # all ok
          else
            @error[:error].push I18n.t :geo, scope: [:validation, :errors], data: data, template: template['label']
            #@error[:error].push "Wrong data type given for #{template['label']} (#{data}). Expected an geometric/geographical type."
          end
          return @error
        end

      end
    end
  end
end
