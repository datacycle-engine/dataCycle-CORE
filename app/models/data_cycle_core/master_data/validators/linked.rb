module DataCycleCore
  module MasterData
    module Validators
      class Linked < BasicValidator
        def keywords
          ['min', 'max']
        end

        def validate(data, template)
          if blank?(data)
            (@error[:warning][@template_key] ||= []) << I18n.t(:no_data, scope: [:validation, :warnings], data: template['label'], locale: DataCycleCore.ui_language)
            # @error[:warning].push "No data given for #{template['label']}."
          elsif data.is_a?(::Array) || data.is_a?(ActiveRecord::Relation)
            check_reference_array(data, template)
          elsif data.is_a?(::String)
            check_reference_array([data], template)
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:data_type, scope: [:validation, :errors], data: data, template: template['label'], locale: DataCycleCore.ui_language)
          end
          @error
        end

        private

        def check_reference_array(data, template)
          converted_data = data.deep_dup
          converted_data = converted_data.ids if data.is_a?(ActiveRecord::Relation)
          # validate given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              if keywords.include?(key)
                method(key).call(converted_data, template['validations'][key])
              else
                (@error[:error][@template_key] ||= []) << I18n.t(:keyword, scope: [:validation, :warnings], key: key, type: 'EmbeddedLinkArray', locale: DataCycleCore.ui_language)
              end
            end
          end

          # validate references
          converted_data.each do |key|
            validate_reference(key, template)
          end
        end

        def validate_reference(key, template)
          if key.is_a?(::String)
            check_reference(key, template)
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:data_format, scope: [:validation, :errors], key: key, template: template['label'], locale: DataCycleCore.ui_language)
          end
        end

        def check_reference(key, template)
          if uuid?(key)
            data_set = "DataCycleCore::#{template['linked_table'].classify}".constantize.where(id: key)
            (@error[:error][@template_key] ||= []) << I18n.t(:not_found, scope: [:validation, :errors], key: key, template: template['label'], table: template['linked_table'], locale: DataCycleCore.ui_language) if data_set.count < 1
          end
        end

        # validate nil,"",[],[nil],[""] as blank.
        def blank?(data)
          return true if data.blank?
          if data.is_a?(::Array)
            return true if data.length == 1 && data[0].blank?
          end
          false
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
