# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Classification
        def classification_alias_ids_with_subtree(ids = nil)
          return self if ids.blank?
          query_string = Thing.send(:sanitize_sql_for_conditions, ['(searches.classification_aliases_mapping && ARRAY[?]::uuid[] OR searches.classification_ancestors_mapping && ARRAY[?]::uuid[])', ids, ids])
          reflect(
            @query.where(search_exists(Arel.sql(query_string)))
          )
        end

        def not_classification_alias_ids_with_subtree(ids = nil)
          return self if ids.blank?
          query_string = Thing.send(:sanitize_sql_for_conditions, ['(classification_aliases_mapping && ARRAY[?]::uuid[] OR classification_ancestors_mapping && ARRAY[?]::uuid[])', ids, ids])
          reflect(
            @query.where.not(search_exists(Arel.sql(query_string)))
          )
        end

        def classification_alias_ids_without_subtree(ids = nil)
          return self if ids.blank?
          query_string = Thing.send(:sanitize_sql_for_conditions, ['classification_aliases_mapping && ARRAY[?]::uuid[]', ids])
          reflect(
            @query.where(search_exists(Arel.sql(query_string)))
          )
        end

        def not_classification_alias_ids_without_subtree(ids = nil)
          return self if ids.blank?
          query_string = Thing.send(:sanitize_sql_for_conditions, ['classification_aliases_mapping && ARRAY[?]::uuid[]', ids])
          reflect(
            @query.where.not(search_exists(Arel.sql(query_string)))
          )
        end

        def with_classification_aliases_and_treename(definition)
          return self if definition.blank?
          raise StandardError, 'Missing data definition: treeLabel' if definition.dig('treeLabel').blank?
          raise StandardError, 'Missing data definition: aliases' if definition.dig('aliases').blank?

          with_classification_aliases(definition.dig('treeLabel'), definition.dig('aliases'))
        end

        def with_classification_aliases(tree_name, *aliases)
          sub_query = DataCycleCore::Thing
            .joins(:classification_aliases)
            .merge(
              DataCycleCore::ClassificationAlias
                .for_tree(tree_name)
                .with_internal_name(aliases)
                .with_descendants
            )

          reflect(
            @query.where(id: sub_query)
          )
        end

        # TODO: Update with classification refactoring: SO SLOW !!!
        def classification_tree_ids(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(
              join_classification_trees_on_classification_content.where(classification_content[:content_data_id].eq(thing[:id]).and(classification_tree[:classification_tree_label_id].in(ids))).exists
            )
          )
        end

        # TODO: Update with classification refactoring: SO SLOW !!!
        def not_classification_tree_ids(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(
              thing[:id].not_in(
                join_classification_trees.where(classification_tree[:classification_tree_label_id].in(ids))
              )
            )
          )
        end

        # Deprecated: replace with classification_alias_ids_with_subtree
        def classification_alias_ids(_ids = nil)
          raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
        end

        # Deprecated: replace with not_classification_alias_ids_with_subtree
        def not_classification_alias_ids(_ids = nil)
          raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
        end

        # Deprecated: replace with classification_alias_ids_without_subtree
        def with_classification_alias_ids_without_recursion(_ids = nil)
          raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
        end
      end
    end
  end
end
