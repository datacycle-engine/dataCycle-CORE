module DataCycleCore
  module ClassificationHelper

    #todo refactor
    def get_classifications_for_name(name)

      if !name.nil? && !name.blank?
        unless (DataCycleCore::ClassificationTreeLabel.find_by name: name).nil?
          @classification_tree_label =  DataCycleCore::ClassificationTreeLabel.find_by name: name
        end
      end

    end

    #todo refactor
    def get_classifications_for_id(uids, treeLabel = nil)

      unless uids.nil?
        if !treeLabel.nil?
          allowed_classifications = get_classifications_for_name(treeLabel).classification_trees.map { |classification| classification.sub_classification_alias.id }
          allowed_uids = uids.select {|uid| allowed_classifications.include?(uid)}
          @selected_classifications = DataCycleCore::ClassificationAlias.find(allowed_uids) rescue return
        else
          @selected_classifications = DataCycleCore::ClassificationAlias.find(uids) rescue return
        end
      end

    end

    #todo refactor
    def get_classificationAliases_for_classificationIDs(uids)
      result = []
      unless uids.nil?
        DataCycleCore::Classification.find(uids).each do |classification|
          result.push(classification.classification_aliases[0])
        end
      end
    end

    def get_selected_values_for_classification(options, value)

      if value.nil?
        return nil
      end

      #todo: make this more fancy
      @selected_values = []
      value.each do |v|
        options.each do |o|
          if o['value'][0] == v
            @selected_values.push(o)
          end
        end
      end

      return @selected_values

    end

    def test_function
      test = 'lala'
    end

  end
end
