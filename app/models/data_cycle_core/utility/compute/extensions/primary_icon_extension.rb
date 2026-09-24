# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Extensions
        # Computes the "Haupt-Icon" (primary icon) classifications of a content:
        # one icon-bearing concept per configured tree, either manually overridden
        # or derived from the content's assigned classifications.
        module PrimaryIconExtension
          # Merges manually maintained "Haupt-Icon" override attributes with an automatic
          # fallback. Every compute parameter that is a classification property with a
          # tree_label acts as an override for its tree; parameters are grouped by tree and
          # the first non-blank override in parameter order wins (so a manual icon listed
          # before a computed effective classification takes precedence). When a tree has no
          # non-blank override, the content's assigned classifications (including mapping-derived
          # and broader ancestors) are used. In every case the result is the nearest concept that
          # actually has an icon (DataCycleCore.classification_icons): for an override the picked
          # concept or its nearest icon-bearing ancestor, for the fallback the first assigned
          # icon-bearing concept in tree order. This handles the common case where contents are
          # mapped onto leaf concepts while only top-level categories carry icons.
          #
          # Example:
          #   :compute:
          #     :module: Classification
          #     :method: primary_icon_classifications
          #     :fallback: false
          #     :recompute_on_classification_change: true
          #     :parameters:
          #       - primary_icon_tags # manual icon, wins for its tree when set
          #       - effective_tags    # computed classification, same tree, used when the manual icon is blank
          #       - universal_classifications
          def primary_icon_classifications(computed_parameters:, content:, key:, **_args)
            overrides, candidates = computed_parameters.partition { |k, _v| content.properties_for(k)&.dig('tree_label').present? }
            candidate_ids = candidates.flat_map { |_k, v| Array.wrap(v) }.compact_blank
            # the computed attribute and the overrides store their own rows in
            # collected_concept_contents; exclude them from the fallback so a
            # previously computed value (or the override assignment) can't feed back into itself
            excluded_relations = overrides.map(&:first) + [key]

            overrides
              .group_by { |override_key, _v| content.properties_for(override_key)['tree_label'] }
              .filter_map do |tree_label, params|
                override_ids = params.map { |_k, v| Array.wrap(v).compact_blank }.find(&:present?)

                if override_ids.present?
                  override_icon_concept_id(override_ids, tree_label)
                else
                  assigned_icon_concept_id(content, tree_label, candidate_ids, excluded_relations)
                end
              end
          end

          private

          # Override: the picked concept, or — if it has no icon — its nearest ancestor
          # (within the tree) that does. Walks concept_path (self first, then
          # ancestors), independent of the collected-concepts trigger so it is
          # correct within the same save that sets the override.
          def override_icon_concept_id(concept_ids, tree_label)
            ordered_concept_ids = DataCycleCore::Concept.where(id: concept_ids)
              .for_tree(tree_label)
              .preload(:concept_path)
              .flat_map { |c| c.concept_path&.full_path_ids || [c.id] }

            first_icon_concept_id(ordered_concept_ids, ordered: true)
          end

          # Fallback: the first assigned (collected, incl. mapping-derived and broader)
          # concept in the tree that has an icon, in tree order. candidate_ids from
          # compute parameters (e.g. universal_classifications) cover assignments made in
          # the same save that are not yet reflected in collected_concept_contents;
          # their ancestors are included so a same-save assignment onto a leaf still resolves
          # to an icon-bearing top-level category. Hidden mappings (#47172) do not classify the
          # content for display, so they are excluded here — the icon follows the visible (or
          # computed effective) classifications, e.g. the "Effektive BayernCloud Klassifizierung"
          # of #47053.
          def assigned_icon_concept_id(content, tree_label, candidate_ids, excluded_relations)
            return if content.new_record?

            ccc = content.collected_concept_contents.without_hidden
            collected_ids = ccc.where.not(relation: excluded_relations).or(ccc.where(relation: nil)).pluck(:concept_id)

            concept_ids = DataCycleCore::Concept
              .for_tree(tree_label)
              .where(id: (collected_ids + ancestry_concept_ids(candidate_ids)).uniq)
              .pluck(:id)

            first_icon_concept_id(concept_ids)
          end

          # ids of the given concepts, of the concepts mapping them, and of all their ancestors.
          # Hidden mappings (#47172/#50677) are excluded so a mapping whose parent sits in a scheme
          # flagged with hidden_mappings does not leak into the icon.
          def ancestry_concept_ids(concept_ids)
            return [] if concept_ids.blank?

            mapping_ids = DataCycleCore::ConceptLink.related.visible.where(child_id: concept_ids).pluck(:parent_id)

            DataCycleCore::Concept.where(id: concept_ids + mapping_ids)
              .preload(:concept_path)
              .flat_map { |c| c.concept_path&.full_path_ids || [c.id] }
          end

          # Given concept ids, return the id of the first one that has an icon. ordered: true keeps
          # the given order (nearest-first ancestry); otherwise tree order (order_a) via the default
          # scope applies.
          def first_icon_concept_id(concept_ids, ordered: false)
            return if concept_ids.blank?

            concepts = DataCycleCore::Concept
              .where(id: concept_ids)
              .preload(:concept_scheme, :concept_path)
            concepts = concepts.index_by(&:id).values_at(*concept_ids).compact if ordered

            concepts.detect(&:icon?)&.id
          end
        end
      end
    end
  end
end
