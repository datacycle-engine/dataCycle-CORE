# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Asset < BasicValidator
        def asset_keywords
          []
        end

        def validate(data, template)
          if blank?(data)
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warnings], data: template['label'], locale: DataCycleCore.ui_language)
          elsif data.is_a?(::Array)
            check_reference_array(data, template)
          elsif data.is_a?(::String)
            check_reference_array([data], template)
          else
            (@error[:warning][@template_key] ||= []) << I18n.t(:data_type, scope: [:validation, :warnings], data: data, locale: DataCycleCore.ui_language)
          end
          @error
        end

        private

        def check_reference_array(data, template)
          # check given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              if asset_keywords.include?(key)
                # method(key).call(data, template['validations'][key]) # no keywords
              else
                (@error[:warning][@template_key] ||= []) << I18n.t(:keyword, scope: [:validation, :warnings], key: key, type: 'Asset reference List', locale: DataCycleCore.ui_language)
              end
            end
          end

          # validate references themself
          data.each do |key|
            if key.is_a?(::String)
              check_reference(key, template)
            else
              (@error[:warning][@template_key] ||= []) << I18n.t(:data_array_format, scope: [:validation, :warnings], data: key, template: template['label'], locale: DataCycleCore.ui_language)
            end
          end
        end

        def check_reference(key, template)
          return unless uuid?(key)
          find_asset = DataCycleCore::Asset.find(key)
          (@error[:warning][@template_key] ||= []) << I18n.t(:asset_upload, scope: [:validation, :errors], locale: DataCycleCore.ui_language) if !check_asset_type(find_asset, template) || find_asset.nil?
        end

        def check_asset_type(asset, template)
          (asset.type == "DataCycleCore::#{template.dig('asset_type').camelize}")
        end

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
