# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Classification
        def classification_alias_ids_with_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(sub_query_for_ccc_relations(ids, 'full_classification_alias_ids'))
          )
        end

        def not_classification_alias_ids_with_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where.not(sub_query_for_ccc_relations(ids, 'full_classification_alias_ids'))
          )
        end

        def classification_alias_ids_without_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(sub_query_for_ccc_relations(ids, 'direct_classification_alias_ids'))
          )
        end

        def not_classification_alias_ids_without_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where.not(sub_query_for_ccc_relations(ids, 'direct_classification_alias_ids'))
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

        def classification_tree_ids(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(sub_query_for_ccc_relations(ids, 'full_tree_label_ids'))
          )
        end

        def not_classification_tree_ids(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where.not(sub_query_for_ccc_relations(ids, 'full_tree_label_ids'))
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

        def sub_query_for_ccc_relations(ids, column_name)
          raw_query = <<-SQL.squish
            SELECT 1
          	FROM collected_classification_contents
            WHERE collected_classification_contents.thing_id = things.id
              AND collected_classification_contents.#{column_name} && ARRAY[?]::UUID[]
          SQL

          Arel::Nodes::Exists.new(Arel.sql(DataCycleCore::Thing.send(:sanitize_sql_for_conditions, [raw_query, ids])))
        end
      end
    end
  end
end
