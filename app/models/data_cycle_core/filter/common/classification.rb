# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Classification
        def concept_ids_with_subtree(ids = nil)
          return self if ids.blank?

          reflect(@query.where(sub_query_for_concept_ids(ids, false)))
        end

        def not_concept_ids_with_subtree(ids = nil)
          return self if ids.blank?

          reflect(@query.where.not(sub_query_for_concept_ids(ids, false)))
        end

        # `concept_ids` is the spelling the whole filter vocabulary shares - a stored filter's `t`,
        # the advanced_filter keys in features.yml, the role parameters in
        # config/configurations/permissions and the `filter_groups.*` translations - while
        # ApiService#apply_classifications_filters composes the long form from the API v4 filter key
        # (`filter[classifications][withSubtree]`). Including the subtree is what both have always meant.
        alias concept_ids concept_ids_with_subtree
        alias not_concept_ids not_concept_ids_with_subtree

        def concept_ids_without_subtree_with_related(ids = nil)
          return self if ids.blank?

          reflect(@query.where(sub_query_for_concept_ids(ids, true, true)))
        end

        def not_concept_ids_without_subtree_with_related(ids = nil)
          return self if ids.blank?

          reflect(@query.where.not(sub_query_for_concept_ids(ids, true, true)))
        end

        def concept_ids_related(ids = nil)
          return self if ids.blank?

          reflect(@query.where(sub_query_for_concept_ids(ids, false, true)))
        end

        def not_concept_ids_related(ids = nil)
          return self if ids.blank?

          reflect(@query.where.not(sub_query_for_concept_ids(ids, false, true)))
        end

        def concept_ids_without_subtree(ids = nil)
          return self if ids.blank?

          reflect(@query.where(sub_query_for_concept_ids(ids, true)))
        end

        def not_concept_ids_without_subtree(ids = nil)
          return self if ids.blank?

          reflect(@query.where.not(sub_query_for_concept_ids(ids, true)))
        end

        def with_classification_paths(paths)
          return self if paths.blank?

          concept_ids_with_subtree(DataCycleCore::Concept.by_full_paths(paths).pluck(:id))
        end

        def not_with_classification_paths(paths)
          return self if paths.blank?

          not_concept_ids_with_subtree(DataCycleCore::Concept.by_full_paths(paths).pluck(:id))
        end

        def with_classification_aliases_and_treename(definition)
          return self if definition.blank?
          raise StandardError, 'Missing data definition: treeLabel' if definition['treeLabel'].blank?
          raise StandardError, 'Missing data definition: aliases' if definition['aliases'].blank?

          concept_ids_with_subtree(DataCycleCore::Concept
            .for_tree(definition['treeLabel'])
            .with_internal_name(definition['aliases']).pluck(:id))
        end

        def not_with_classification_aliases_and_treename(definition)
          return self if definition.blank?
          raise StandardError, 'Missing data definition: treeLabel' if definition['treeLabel'].blank?
          raise StandardError, 'Missing data definition: aliases' if definition['aliases'].blank?

          not_concept_ids_with_subtree(DataCycleCore::Concept
            .for_tree(definition['treeLabel'])
            .with_internal_name(definition['aliases']).pluck(:id))
        end

        def concept_scheme_ids(ids = nil)
          return self if ids.blank?

          reflect(@query.where(sub_query_for_concept_scheme_ids(ids)))
        end

        def not_concept_scheme_ids(ids = nil)
          return self if ids.blank?

          reflect(@query.where.not(sub_query_for_concept_scheme_ids(ids)))
        end

        def user_group_classifications(user_id)
          return self if user_id.nil?

          ids = DataCycleCore::Concept
            .joins(user_groups: :user_group_users)
            .where(user_group_users: { user_id: })
            .pluck(:id)

          return reflect(DataCycleCore::Thing.none) if ids.blank?

          reflect(@query.where(sub_query_for_concept_ids(ids, false)))
        end

        private

        def sub_query_for_concept_ids(ids, direct = false, related = false)
          link_types = []
          link_types << 'direct' if direct
          link_types << 'related' if related

          query = DataCycleCore::CollectedConceptContent.without_hidden.where(concept_id: ids) # #47172: never filter on hidden mappings
          query = query.where(link_type: link_types) if link_types.present?
          query.where(ccc_table[:thing_id].eq(thing[:id]))
            .select(1)
            .arel.exists
        end

        def sub_query_for_concept_scheme_ids(ids, direct = false)
          query = DataCycleCore::CollectedConceptContent
            .without_hidden # #47172: never filter on hidden mappings
            .where(concept_scheme_id: ids)

          query = query.where(link_type: 'direct') if direct
          query.where(ccc_table[:thing_id].eq(thing[:id]))
            .select(1)
            .arel.exists
        end
      end
    end
  end
end
