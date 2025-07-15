# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Asset < BasicValidator
        def validate(data, template, _strict = false)
          check_reference_array(Array(data), template)

          @error
        end

        private

        def check_reference_array(data, template)
          # check given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              validate_with_method(key, data, template['validations'][key])
            end
          end

          return if blank?(data)

          # validate references themself
          data.each do |key|
            if key.is_a?(::String)
              check_reference(key, template)
            elsif key.is_a?(DataCycleCore::Asset)
              check_reference(key.id, template)
            else
              (@error[:error][@template_key] ||= []) << {
                path: 'validation.errors.data_array_format',
                substitutions: {
                  key:,
                  template: template['label']
                }
              }
            end
          end
        end

        def check_reference(key, template)
          return unless uuid?(key)
          find_asset = DataCycleCore::Asset.find(key)
          (@error[:warning][@template_key] ||= []) << { path: 'validation.errors.asset_upload' } if !check_asset_type(find_asset, template) || find_asset.nil?
        end

        def check_asset_type(asset, template) # rubocop:disable Naming/PredicateMethod
          (asset.type == "DataCycleCore::#{template['asset_type'].camelize}")
        end

        def required(data, value)
          (@error[:error][@template_key] ||= []) << { path: 'validation.errors.required' } if value && blank?(data)
        end
      end
    end
  end
end
