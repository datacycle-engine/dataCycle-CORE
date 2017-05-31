module DataCycleCore
  module MasterData
    module Validators
      class ClassificationTreeLabel < BasicValidator

        def validate(data, template)
          puts "---> validate classificationTreeLabel, data:'#{data}'"
          if data.blank?
            @error[:warning].push "No data given for #{template['label']}."
          elsif data.is_a?(::Array)
            data.each do |key|
              if key.is_a?(::String)
                check_reference(key,template) unless key.blank?
              else
                @error[:error].push "Elements of the data-array given for #{template['label']} have the wrong format (#{key})."
              end
            end
          elsif data.is_a?(::String)
            check_reference(data,template)
          else
            @error[:error].push "Wrong data type given for #{template['label']} (#{data}). Expected an UUID or an array of UUID's."
          end
          return @error
        end

        def check_reference(key, template)
          if uuid?(key)
            find_classification_alias = DataCycleCore::ClassificationTree.
              joins(:classification_tree_label).
              joins(sub_classification_alias: [classification_groups: [:classification]]).
              where("classifications.id = ? ", key).
              where("classification_tree_labels.name = ?", template['type_name'])
            if find_classification_alias.count < 1
              @error[:error].push "In classification_tree with label: \"#{template['label']}\" and tree-label \"#{template['type_name']}\". No respective Classification found for #{key}."
            end
          end
        end

        def uuid?(data)
          data.downcase!
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data.length == 36 && !(data=~uuid).nil?
          unless check_uuid
            @error[:error].push "Expecting uuid for #{data}. format: 12345678-9abc-def0-1234-56789abcdef0"
          end
          check_uuid
        end

      end
    end
  end
end
