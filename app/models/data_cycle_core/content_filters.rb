module DataCycleCore
  module ContentFilters
    def with_classification_alias_names(*names)
      where(id: name.constantize.joins(:classification_aliases)
        .merge(ClassificationAlias.with_name(names.flatten).with_descendants))
    end

    def with_classification_alias_ids(*ids)
      where(id: name.constantize.joins(:classification_aliases)
        .merge(ClassificationAlias.where(id: ids).with_descendants))
    end
  end
end
