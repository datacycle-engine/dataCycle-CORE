module DataCycleCore
  module ClassificationHelper
    # TODO: refactor
    def get_classifications_for_name(name)
      if !name.nil? && !name.blank?
        DataCycleCore::ClassificationTreeLabel
          .includes(classification_trees: [:classification_tree_label, :sub_classification_alias])
          .find_by(name: name)
      end
    end

    # TODO: refactor
    def get_classifications_for_id(uids, treeLabel = nil)
      unless uids.nil?
        if !treeLabel.nil?
          allowed_classifications = get_classifications_for_name(treeLabel)
            .classification_trees
            .map { |classification| classification.sub_classification_alias.id }
          allowed_uids = uids.select { |uid| allowed_classifications.include?(uid) }
          @selected_classifications = DataCycleCore::ClassificationAlias.find(allowed_uids)
        else
          @selected_classifications = DataCycleCore::ClassificationAlias.find(uids)
        end
      end
    rescue
      logger.warn("cannot find classifications for the following ids: #{(uids || []).join(', ')}")
      nil
    end

    # TODO: refactor
    def get_classificationAliases_for_classificationIDs(uids)
      result = []
      unless uids.nil?
        DataCycleCore::Classification.where(id: uids).each do |classification|
          result.push(classification.classification_aliases[0])
        end
      end
    end

    def get_selected_values_for_classification(options, value)
      return nil if value.nil?

      # TODO: make this more fancy
      @selected_values = []
      Array(value).each do |v|
        options.each do |o|
          @selected_values.push(o) if o[1] == v
        end
      end

      return @selected_values
    end

    def get_custom_select_values(classification_alias)
      res = walk_classification_tree(classification_alias)
    end

    def ordered_content_pools
      content_pool_order = ['Vorschläge', 'Recherche', 'Aktuelle Inhalte', 'Archiv']
      pools = Hash[DataCycleCore::ClassificationAlias.where(name: content_pool_order).collect { |c| [c.try(:name), c] }]
      cached_ordered_content_pools = content_pool_order.collect { |c| { id: pools[c].classifications.ids.first, alias: pools[c] } } unless pools.blank?
      cached_ordered_content_pools
    end

    def walk_classification_tree(classification_alias)
      classification_tree = []
      return if classification_alias.nil?
      classification_alias.each do |value|
        classification_tree.push([value.name, value.classifications.ids.first])
        classification_tree.push(walk_classification_tree(value.sub_classification_alias).flatten)
      end
      classification_tree
    end
  end
end
