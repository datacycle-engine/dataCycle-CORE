module DataCycleCore
  module ClassificationHelper

    #todo refactor
    def get_classifications_for_name(name)
      if !name.nil? && !name.blank?
        DataCycleCore::ClassificationTreeLabel
          .includes(classification_trees: [:classification_tree_label, :sub_classification_alias])
          .find_by name: name
      end
    end

    #todo refactor
    def get_classifications_for_id(uids, treeLabel = nil)

      unless uids.nil?
        if !treeLabel.nil?
          allowed_classifications = get_classifications_for_name(treeLabel)
            .classification_trees
            .map { |classification| classification.sub_classification_alias.id }
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
        DataCycleCore::Classification.where(id: uids).each do |classification|
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
          if o[:value] == v
            @selected_values.push(o)
          end
        end
      end

      return @selected_values

    end

    def get_custom_select_values(classification_alias)
      res = walk_classification_tree(classification_alias).flatten
    end

    def ordered_content_pools
      content_pool_order = ['Vorschläge', 'Recherche', 'Aktuelle Inhalte', 'Archiv']
      pools = Hash[DataCycleCore::ClassificationAlias.where(name: content_pool_order).collect{ |c| [ c.try(:name), c ] }]
      unless pools.blank?
        cached_ordered_content_pools = content_pool_order.collect{ |c| {id: pools[c].classifications.ids.first, alias: pools[c]} }
      end
      cached_ordered_content_pools
    end

    def get_next_content_pool(classification_id)
      unless ordered_content_pools.nil?
        c_index = ordered_content_pools.index{ |c| c[:id] == classification_id }
        if c_index < ordered_content_pools.length - 1
          return ordered_content_pools[c_index + 1]
        end
      end
    end

    def walk_classification_tree(classification_alias,level=0)
      classification_tree = []
      return if classification_alias.nil?
      classification_alias.each do |value|
        classification_tree.push({:value => value.classifications.ids.first, :label => value.name, :level => level})
        if value.sub_classification_alias.count > 0
          level += 1
          classification_tree.push(walk_classification_tree(value.sub_classification_alias, level))
          level -= 1
        end
      end
      classification_tree
    end

  end
end
