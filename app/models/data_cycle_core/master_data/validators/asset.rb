module DataCycleCore
  module MasterData
    module Validators
      class Asset < BasicValidator
        @@keywords = ['min', 'max']

        def validate(data, template)
          if data.is_a?(::Array)
            check_reference_array(data, template)
          elsif data.is_a?(::String)
            check_reference_array([data], template)
          else
            (@error[:warning][key] ||= []) << I18n.t(:data_type, scope: [:validation, :warning], data: data, locale: DataCycleCore.ui_language)
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
                (@error[:warning][key] ||= []) << I18n.t(:keyword, scope: [:validation, :warning], data: key, type: 'Asset reference List', locale: DataCycleCore.ui_language)
              end
            end
          end

          # validate references themself
          data.each do |key|
            if key.is_a?(::String)
              check_reference(key)
            else
              (@error[:warning][key] ||= []) << I18n.t(:data_array_format, scope: [:validation, :warning], data: key, template: template['label'], locale: DataCycleCore.ui_language)
            end
          end
        end

        def check_reference(key)
          if uuid?(key)
            find_asset = DataCycleCore::Asset.find(key)
            (@error[:warning][key] ||= []) << I18n.t(:asset_upload, scope: [:validation, :warning], locale: DataCycleCore.ui_language) if find_asset.nil?
          end
        end

        def uuid?(data)
          data.downcase!
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data.length == 36 && !(data =~ uuid).nil?
          (@error[:warning][@template_key] ||= []) << I18n.t(:uuid, scope: [:validation, :warning], data: data, locale: DataCycleCore.ui_language) unless check_uuid
          check_uuid
        end

        def min(data, value)
          (@error[:error][@template_key] ||= []) << I18n.t(:min_ref, scope: [:validation, :errors], data: data.size, value: value, locale: DataCycleCore.ui_language) if data.size < value
        end

        def max(data, value)
          (@error[:error][@template_key] ||= []) << I18n.t(:max_ref, scope: [:validation, :errors], data: data.size, value: value, locale: DataCycleCore.ui_language) if data.size > value
        end
      end
    end
  end
end
