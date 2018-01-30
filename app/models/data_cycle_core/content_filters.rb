module DataCycleCore
  module ContentFilters
    def with_classification_aliase_names(*names)
      joins(:classification_aliases)
        .where(classification_aliases: { id: ClassificationAlias.with_name(names.flatten) })
    end
  end
end
