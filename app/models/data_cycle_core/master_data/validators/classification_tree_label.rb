module MasterData
  module Validators
    class ClassificationTreeLabel < BasicValidator

      def validate(data, template)
        data.each do |key|
          if uuid?(key)
            find_classification_alias = DataCycleCore::ClassificationTree
              .joins(:classification_tree_label)
              .where(classification_alias_id: key)
              .where("classification_tree_labels.name = ?", template['label'])
            if find_classification_alias.count < 1
              @error[:error].push "In classification_tree with label: \"#{template['label']}\". No respective ClassificationAlias found for #{key}."
            end
          end
        end
        return @error
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
