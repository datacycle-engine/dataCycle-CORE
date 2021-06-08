# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Classification
        def classification_alias_ids_with_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(create_exists_query_for_classification_alias_ids_with_subtree(ids))
          )
        end

        def not_classification_alias_ids_with_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(Arel::Nodes::Not.new(create_exists_query_for_classification_alias_ids_with_subtree(ids)))
          )
        end

        def classification_alias_ids_without_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(create_exists_query_for_classification_alias_ids_without_subtree(ids))
          )
        end

        def not_classification_alias_ids_without_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(Arel::Nodes::Not.new(create_exists_query_for_classification_alias_ids_without_subtree(ids)))
          )
        end

        def with_classification_aliases_and_treename(definition)
          return self if definition.blank?
          raise StandardError, 'Missing data definition: treeLabel' if definition.dig('treeLabel').blank?
          raise StandardError, 'Missing data definition: aliases' if definition.dig('aliases').blank?

          classification_alias_ids_with_subtree(DataCycleCore::ClassificationAlias
            .for_tree(definition.dig('treeLabel'))
            .with_internal_name(definition.dig('aliases')).pluck(:id))
        end

        # TODO: Delete if not used anymore
        # def with_classification_aliases(tree_name, *aliases)
        #   sub_query = DataCycleCore::Thing
        #     .joins(:classification_aliases)
        #     .merge(
        #       DataCycleCore::ClassificationAlias
        #         .for_tree(tree_name)
        #         .with_internal_name(aliases)
        #         .with_descendants
        #     )

        #   reflect(
        #     @query.where(id: sub_query)
        #   )
        # end

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

        private

        def create_exists_query_for_classification_alias_ids_with_subtree(ids)
          raw_query = <<-SQL.squish
            SELECT
          	FROM classification_alias_paths
          	JOIN classification_groups ON
              classification_groups.classification_alias_id = classification_alias_paths.id
          	JOIN classification_contents ON
              classification_contents.classification_id = classification_groups.classification_id
          	WHERE classification_contents.content_data_id = things.id AND
              classification_alias_paths.full_path_ids && ARRAY[?]::UUID[]
          SQL

          Arel::Nodes::Exists.new(
            Arel.sql(
              Thing.send(:sanitize_sql_for_conditions,
                [
                  raw_query,
                  ids
                ]
              )
            )
          )
        end

        def create_exists_query_for_classification_alias_ids_without_subtree(ids)
          raw_query = <<-SQL.squish
            SELECT
        	  FROM classification_groups
        	  JOIN classification_contents ON
              classification_contents.classification_id = classification_groups.classification_id
        	  WHERE classification_contents.content_data_id = things.id AND
              classification_groups.classification_alias_id IN (?)
          SQL

          Arel::Nodes::Exists.new(
            Arel.sql(
              Thing.send(:sanitize_sql_for_conditions,
                [
                  raw_query,
                  ids
                ]
              )
            )
          )
        end
      end
    end
  end
end
