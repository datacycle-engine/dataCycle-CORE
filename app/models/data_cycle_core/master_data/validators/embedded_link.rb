module DataCycleCore
  module MasterData
    module Validators
      class EmbeddedLink < BasicValidator

        # only allow single uuid referencing to a given table
        def validate(data, template)
          if data.blank?
            @error[:warning].push I18n.t :no_data, scope: [:validation, :warning], data: template['label']
            #@error[:warning].push "No data given for #{template['label']}."
          elsif data.is_a?(::String)
            check_reference(data,template)
          else
            @error[:error].push I18n.t :data_type, scope: [:validation, :errors], data: data, template: template['label']
            #@error[:error].push "Wrong data type given for #{template['label']} (#{data}). Expected an UUID or an array of UUID's."
          end
          return @error
        end

        def check_reference(key, template)
          if uuid?(key)
            data_set = "DataCycleCore::#{template['type_name'].classify}".constantize.where(id: key)
            if data_set.count < 1
              @error[:error].push I18n.t :not_found, scope: [:validation, :errors], key: key, template: template['label'], table: template['type_name']
              #@error[:error].push "Given data for #{template['label']} with uuid (#{key}) not found in table #{template['type_name']}."
            end
          end
        end

        def uuid?(data)
          data.downcase!
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data.length == 36 && !(data=~uuid).nil?
          unless check_uuid
            @error[:error].push I18n.t :uuid, scope: [:validation, :errors], data: data
            #@error[:error].push "Expecting uuid for #{data}. format: 12345678-9abc-def0-1234-56789abcdef0"
          end
          check_uuid
        end

      end
    end
  end
end
