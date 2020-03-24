# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Classification
        def classification_alias_ids(ids = nil)
          return self if ids.blank?
          ids = DataCycleCore::ClassificationAlias.where(id: ids).with_descendants.select(:id).arel

          reflect(
            @query.where(
              join_classification_alias_on_classification_content.where(classification_content[:content_data_id].eq(thing[:id]).and(classification_alias[:id].in(ids))).exists
            )
          )
        end

        def not_classification_alias_ids(ids = nil)
          return self if ids.blank?

          reflect(@query.without_classification_alias_ids(ids))
        end

        def classification_tree_ids(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(
              join_classification_trees_on_classification_content.where(classification_content[:content_data_id].eq(thing[:id]).and(classification_tree[:classification_tree_label_id].in(ids))).exists
            )
          )
        end

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

        def classification_alias_ids_with_subtree(ids = nil)
          return self if ids.blank?
          query_string = Thing.send(:sanitize_sql_for_conditions, ['classification_aliases_mapping && ARRAY[?]::uuid[] OR classification_ancestors_mapping && ARRAY[?]::uuid[]', ids, ids])
          reflect(
            @query.where(query_string)
          )
        end

        def not_classification_alias_ids_with_subtree(ids = nil)
          return self if ids.blank?
          query_string = Thing.send(:sanitize_sql_for_conditions, ['classification_aliases_mapping && ARRAY[?]::uuid[] OR classification_ancestors_mapping && ARRAY[?]::uuid[]', ids, ids])
          reflect(
            @query.where.not(query_string)
          )
        end

        def classification_alias_ids_without_subtree(ids = nil)
          return self if ids.blank?
          query_string = Thing.send(:sanitize_sql_for_conditions, ['classification_aliases_mapping && ARRAY[?]::uuid[]', ids])
          reflect(
            @query.where(query_string)
          )
        end

        def not_classification_alias_ids_without_subtree(ids = nil)
          return self if ids.blank?
          query_string = Thing.send(:sanitize_sql_for_conditions, ['classification_aliases_mapping && ARRAY[?]::uuid[]', ids])
          reflect(
            @query.where.not(query_string)
          )
        end

        def with_classification_alias_ids_without_recursion(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(
              join_classification_alias_on_classification_content.where(classification_content[:content_data_id].eq(thing[:id]).and(classification_alias[:id].in(ids))).exists
            )
          )
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
      end
    end
  end
end
