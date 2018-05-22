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

    def with_content_type(type)
      where("schema ->> 'content_type' = ?", type)
    end

    def expired_not_release_id(id)
      translation_table = "DataCycleCore::#{table_name.classify}::Translation".constantize.arel_table
      joins(:translations)
        .where.not(
          translation_table[:release_id].eq(id)
          .or(translation_table[:release_id].eq(nil))
        )
    end

    def expired_not_life_cycle_id(id)
      if DataCycleCore.features.dig(:life_cycle, :attribute_key).present?
        joins(:classifications)
          .where('classification_contents.relation = ?', DataCycleCore.features.dig(:life_cycle, :attribute_key))
          .where.not('classification_contents.classification_id = ?', id)
      end
    end
  end
end
