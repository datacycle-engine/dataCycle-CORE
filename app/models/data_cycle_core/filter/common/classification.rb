# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Classification
        def classification_alias_ids_with_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(sub_query_for_classification_alias_ids(ids, false))
          )
        end

        def not_classification_alias_ids_with_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where.not(sub_query_for_classification_alias_ids(ids, false))
          )
        end

        def classification_alias_ids_without_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(sub_query_for_classification_alias_ids(ids, true))
          )
        end

        def not_classification_alias_ids_without_subtree(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where.not(sub_query_for_classification_alias_ids(ids, true))
          )
        end

        def with_classification_paths(paths)
          return self if paths.blank?

          classification_alias_ids_with_subtree(DataCycleCore::ClassificationAlias.by_full_paths(paths).pluck(:id))
        end

        def not_with_classification_paths(paths)
          return self if paths.blank?

          not_classification_alias_ids_with_subtree(DataCycleCore::ClassificationAlias.by_full_paths(paths).pluck(:id))
        end

        def with_classification_aliases_and_treename(definition)
          return self if definition.blank?
          raise StandardError, 'Missing data definition: treeLabel' if definition.dig('treeLabel').blank?
          raise StandardError, 'Missing data definition: aliases' if definition.dig('aliases').blank?

          classification_alias_ids_with_subtree(DataCycleCore::ClassificationAlias
            .for_tree(definition.dig('treeLabel'))
            .with_internal_name(definition.dig('aliases')).pluck(:id))
        end

        def not_with_classification_aliases_and_treename(definition)
          return self if definition.blank?
          raise StandardError, 'Missing data definition: treeLabel' if definition.dig('treeLabel').blank?
          raise StandardError, 'Missing data definition: aliases' if definition.dig('aliases').blank?

          not_classification_alias_ids_with_subtree(DataCycleCore::ClassificationAlias
            .for_tree(definition.dig('treeLabel'))
            .with_internal_name(definition.dig('aliases')).pluck(:id))
        end

        def classification_tree_ids(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(sub_query_for_tree_label_ids(ids))
          )
        end

        def not_classification_tree_ids(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where.not(sub_query_for_tree_label_ids(ids))
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

        def user_group_classifications(user_id)
          return self if user_id.nil?

          ids = DataCycleCore::ClassificationAlias
            .includes(classifications: [user_groups: :user_group_users])
            .where(classifications: { user_groups: { user_group_users: { user_id: } } })
            .pluck(:id)

          if ids.blank?
            reflect(@query.where('1 = 0'))
          else
            reflect(@query.where(sub_query_for_classification_alias_ids(ids, false)))
          end
        end

        private

        def sub_query_for_classification_alias_ids(ids, direct = false)
          table_alias = "ccc_#{SecureRandom.hex(6)}"
          raw_query = <<-SQL.squish
            SELECT 1
          	FROM "collected_classification_contents" "#{table_alias}"
            WHERE "#{table_alias}"."thing_id" = "things"."id"
              AND "#{table_alias}"."classification_alias_id" IN (?)
          SQL

          raw_query << " AND \"#{table_alias}\".\"direct\" = TRUE" if direct

          Arel::Nodes::Exists.new(Arel.sql(DataCycleCore::Thing.send(:sanitize_sql_for_conditions, [raw_query, ids])))
        end

        def sub_query_for_tree_label_ids(ids, direct = false)
          table_alias = "ccc_#{SecureRandom.hex(6)}"
          raw_query = <<-SQL.squish
            SELECT 1
          	FROM collected_classification_contents "#{table_alias}"
            WHERE "#{table_alias}"."thing_id" = "things"."id"
              AND "#{table_alias}"."classification_tree_label_id" IN (?)
          SQL

          raw_query << " AND \"#{table_alias}\".\"direct\" = TRUE" if direct

          Arel::Nodes::Exists.new(Arel.sql(DataCycleCore::Thing.send(:sanitize_sql_for_conditions, [raw_query, ids])))
        end
      end
    end
  end
end
