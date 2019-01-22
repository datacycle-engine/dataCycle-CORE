# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Classification < BasicValidator
        def keywords
          ['min', 'max', 'required']
        end

        def validate(data, template)
          if blank?(data)
            check_reference_array(data, template)
          elsif data.is_a?(::Array)
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
          # check given validations
          if template.key?('validations')
            template['validations'].each_key do |key|
              if keywords.include?(key)
                method(key).call(data, template['validations'][key])
              else
                (@error[:warning][@template_key] ||= []) << I18n.t(:keyword, scope: [:validation, :errors], key: key, type: 'ClassificationTreeLabel reference List', locale: DataCycleCore.ui_language)
              end
            end
          end

          # validate references themself
          return if blank?(data)

          data.each do |key|
            if key.is_a?(::String)
              check_reference(key, template)
            else
              (@error[:error][@template_key] ||= []) << I18n.t(:data_array_format, scope: [:validation, :errors], key: key, template: template['label'], locale: DataCycleCore.ui_language)
            end
          end
        end

        def check_reference(key, template)
          return unless uuid?(key)
          find_classification_alias = DataCycleCore::ClassificationTree
            .joins(:classification_tree_label)
            .joins(sub_classification_alias: [classification_groups: [:classification]])
            .where({
              classifications: { id: key },
              classification_tree_labels: { name: template['tree_label'] }
            })

          (@error[:error][@template_key] ||= []) << I18n.t(:classification, scope: [:validation, :errors], key: key, label: template['label'], tree_label: template['tree_label'], locale: DataCycleCore.ui_language) if find_classification_alias.count < 1
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

        def required(data, value)
          (@error[:error][@template_key] ||= []) << I18n.t(:required, scope: [:validation, :errors], locale: DataCycleCore.ui_language) if value && blank?(data)
        end
      end
    end
  end
end
