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

    def search(q, language)
      contents = arel_table
      search_entries = Search.arel_table

      joins(
        contents
          .join(search_entries)
          .on(
            contents[:id].eq(search_entries[:content_data_id])
              .and(search_entries[:content_data_type].eq(name))
              .and(search_entries[:locale].eq(language))
          ).join_sources
      ).where(
        search_entries[:all_text].matches_all(q.split(' ').map(&:strip))
          .or(tsmatch(search_entries[:words], tsquery(quoted(q.squish))))
      )
    end
  end
end
