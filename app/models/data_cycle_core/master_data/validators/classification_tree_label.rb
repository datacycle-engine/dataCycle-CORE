module DataCycleCore
  module MasterData
    module Validators
      class ClassificationTreeLabel < BasicValidator
        @@keywords = ['min', 'max']

        def validate(data, template)
          if is_blank?(data)
            @error[:warning].push I18n.t :no_data, scope: [:validation, :errors], data: template['label'], locale: DataCycleCore.ui_language
          elsif data.is_a?(::Array)
            check_reference_array(data, template)
          elsif data.is_a?(::String)
            check_reference_array([data], template)
          else
            @error[:error].push I18n.t :data_type, scope: [:validation, :errors], data: data, template: template['label'], locale: DataCycleCore.ui_language
          end
          return @error
        end

        private

        def check_reference_array(data, template)
          # check given validations
          if template.has_key?('validations')
            template['validations'].keys.each do |key|
              if @@keywords.include?(key)
                self.method(key).call(data, template['validations'][key])
              else
                @error[:warning].push I18n.t :keyword, scope: [:validation, :errors], key: key, type: "ClassificationTreeLabel reference List", locale: DataCycleCore.ui_language
              end
            end
          end

          # validate references themself
          data.each do |key|
            if key.is_a?(::String)
              check_reference(key, template)
            else
              @error[:error].push I18n.t :data_array_format, scope: [:validation, :errors], key: key, template: template['label'], locale: DataCycleCore.ui_language
            end
          end
        end

        def check_reference(key, template)
          if uuid?(key)
            find_classification_alias = DataCycleCore::ClassificationTree.
              joins(:classification_tree_label).
              joins(sub_classification_alias: [classification_groups: [:classification]]).
              where("classifications.id = ? ", key).
              where("classification_tree_labels.name = ?", template['type_name'])
            if find_classification_alias.count < 1
              @error[:error].push I18n.t :classification, scope: [:validation, :errors], key: key, label: template['label'], tree_label: template['type_name'], locale: DataCycleCore.ui_language
            end
          end
        end

        def uuid?(data)
          data.downcase!
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data.length == 36 && !(data =~ uuid).nil?
          unless check_uuid
            @error[:error].push I18n.t :uuid, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language
          end
          check_uuid
        end

        # validate nil,"",[],[nil],[""] as blank.
        def is_blank?(data)
          return true if data.blank?
          if data.is_a?(::Array)
            return true if data.length == 1 && data[0].blank?
          end
          return false
        end

        def min(data, value)
          if data.size < value
            @error[:error].push I18n.t :min_ref, scope: [:validation, :errors], data: data.size, value: value, locale: DataCycleCore.ui_language
          end
        end

        def max(data, value)
          if data.size > value
            @error[:error].push I18n.t :max_ref, scope: [:validation, :errors], data: data.size, value: value, locale: DataCycleCore.ui_language
          end
        end
      end
    end
  end
end
