module DataCycleCore
  module MasterData
    module Validators
      class Asset < BasicValidator
        def validate(data, template, template_key)
          if blank?(data)
            @error[:warning].push I18n.t :no_data, scope: [:validation, :errors], data: template['label'], locale: DataCycleCore.ui_language
          elsif data.is_a?(::Array)
            check_reference_array(data, template)
          elsif data.is_a?(::String)
            check_reference_array([data], template)
          else
            @error[:error].push I18n.t :data_type, scope: [:validation, :errors], data: data, template: template['label'], locale: DataCycleCore.ui_language
          end
          @error
        end

        private

        def check_reference_array(data, template)
          # check given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              if @@keywords.include?(key)
                method(key).call(data, template['validations'][key])
              else
                @error[:warning].push I18n.t :keyword, scope: [:validation, :errors], key: key, type: 'Asset reference List', locale: DataCycleCore.ui_language
              end
            end
          end

          # validate references themself
          data.each do |key|
            if key.is_a?(::String)
              check_reference(key)
            else
              @error[:error].push I18n.t :data_array_format, scope: [:validation, :errors], key: key, template: template['label'], locale: DataCycleCore.ui_language
            end
          end
        end

        def check_reference(key)
          if uuid?(key)
            find_asset = DataCycleCore::Asset.find(key)
            @error[:error].push I18n.t :asset_upload, scope: [:validation, :errors], locale: DataCycleCore.ui_language if find_asset.nil?
          end
        end

        def uuid?(data)
          data.downcase!
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data.length == 36 && !(data =~ uuid).nil?
          @error[:error].push I18n.t :uuid, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language unless check_uuid
          check_uuid
        end

        # validate nil,"",[],[nil],[""] as blank.
        def blank?(data)
          return true if data.blank?
          if data.is_a?(::Array)
            return true if data.length == 1 && data[0].blank?
          end
          false
        end
      end
    end
  end
end
