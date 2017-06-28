module DataCycleCore
  module MasterData
    module Validators
      class ClassificationTreeLabel < BasicValidator

        @@keywords = ['min', 'max']

        def validate(data, template)
          if is_blank?(data)
            @error[:warning].push "No data given for #{template['label']}."
          elsif data.is_a?(::Array)
            check_reference_array(data, template)
          elsif data.is_a?(::String)
            check_reference_array([data],template)
          else
            @error[:error].push "Wrong data type given for #{template['label']} (#{data}). Expected an UUID or an array of UUID's."
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
                @error[:warning].push "#{key} is not a known keyword for a ClassificationTreeLabel reference List."
              end
            end
          end

          # validate references themself
          data.each do |key|
            if key.is_a?(::String)
              check_reference(key,template)
            else
              @error[:error].push "Elements of the data-array given for #{template['label']} have the wrong format (#{key})."
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
            @error[:error].push "Number of references given (#{data.size}) is smaller than expected. Should be at least #{value}."
          end
        end

        def max(data, value)
          if data.size > value
            @error[:error].push "Too many references given (#{data.size}). Only a maximum of #{value} is allowed."
          end
        end

      end
    end
  end
end
