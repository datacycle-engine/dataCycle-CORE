module DataCycleCore
  module MasterData
    module Validators
      class EmbeddedLink < BasicValidator

        # only allow single uuid referencing to a given table
        def validate(data, template)
          if data.blank?
            @error[:warning].push I18n.t :no_data, scope: [:validation, :warning], data: template['label']
          elsif data.is_a?(::String)
            check_reference(data,template)
          else
            @error[:error].push I18n.t :data_type, scope: [:validation, :errors], data: data, template: template['label']
          end
          return @error
        end

        def check_reference(key, template)
          if uuid?(key)
            data_set = "DataCycleCore::#{template['type_name'].classify}".constantize.where(id: key)
            if data_set.count < 1
              @error[:error].push I18n.t :not_found, scope: [:validation, :errors], key: key, template: template['label'], table: template['type_name']
            end
          end
        end

        def uuid?(data)
          data.downcase!
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data.length == 36 && !(data=~uuid).nil?
          unless check_uuid
            @error[:error].push I18n.t :uuid, scope: [:validation, :errors], data: data
          end
          check_uuid
        end

      end
    end
  end
end
