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
            # collected_classification_contents; exclude them from the fallback so a
            # previously computed value (or the override assignment) can't feed back into itself
            excluded_relations = overrides.map(&:first) + [key]

            overrides
              .group_by { |override_key, _v| content.properties_for(override_key)['tree_label'] }
              .filter_map do |tree_label, params|
                override_ids = params.map { |_k, v| Array.wrap(v).compact_blank }.find(&:present?)

                if override_ids.present?
                  override_icon_classification_id(override_ids, tree_label)
                else
                  assigned_icon_classification_id(content, tree_label, candidate_ids, excluded_relations)
                end
              end
          end

          private

          # Override: the picked concept, or — if it has no icon — its nearest ancestor
          # (within the tree) that does. Walks classification_alias_path (self first, then
          # ancestors), independent of the collected-classifications trigger so it is
          # correct within the same save that sets the override.
          def override_icon_classification_id(classification_ids, tree_label)
            ordered_alias_ids = DataCycleCore::Classification.where(id: classification_ids)
              .classification_aliases.for_tree(tree_label)
              .preload(:classification_alias_path)
              .flat_map { |a| a.classification_alias_path&.full_path_ids || [a.id] }

            first_icon_classification_id(ordered_alias_ids, ordered: true)
          end

          # Fallback: the first assigned (collected, incl. mapping-derived and broader)
          # classification in the tree that has an icon, in tree order. candidate_ids from
          # compute parameters (e.g. universal_classifications) cover assignments made in
          # the same save that are not yet reflected in collected_classification_contents;
          # their ancestors are included so a same-save assignment onto a leaf still resolves
          # to an icon-bearing top-level category. Hidden mappings (#47172) do not classify the
          # content for display, so they are excluded here — the icon follows the visible (or
          # computed effective) classifications, e.g. the "Effektive BayernCloud Klassifizierung"
          # of #47053.
          def assigned_icon_classification_id(content, tree_label, candidate_ids, excluded_relations)
            return if content.new_record?

            ccc = content.collected_classification_contents.without_hidden
            collected_ids = ccc.where.not(relation: excluded_relations).or(ccc.where(relation: nil)).pluck(:classification_alias_id)

            alias_ids = DataCycleCore::ClassificationAlias
              .for_tree(tree_label)
              .where(id: (collected_ids + ancestry_alias_ids(candidate_ids)).uniq)
              .pluck(:id)

            first_icon_classification_id(alias_ids)
          end

          # classification-alias ids of the given classifications plus all their ancestors.
          # Hidden mappings (#47172/#50677) are excluded so a mapping into a tree flagged with
          # hidden_mappings does not leak into the icon; visible mappings and the concept's own
          # (primary) group are kept.
          def ancestry_alias_ids(classification_ids)
            return [] if classification_ids.blank?

            DataCycleCore::Classification.where(id: classification_ids)
              .classification_aliases
              .merge(DataCycleCore::ClassificationGroup.visible)
              .preload(:classification_alias_path)
              .flat_map { |a| a.classification_alias_path&.full_path_ids || [a.id] }
          end

          # Given classification-alias ids, return the primary classification id of the
          # first one that has an icon. ordered: true keeps the given order (nearest-first
          # ancestry); otherwise tree order (order_a) via the default scope applies.
          def first_icon_classification_id(alias_ids, ordered: false)
            return if alias_ids.blank?

            aliases = DataCycleCore::ClassificationAlias
              .where(id: alias_ids)
              .preload(:classification_tree_label, :classification_alias_path)
            aliases = aliases.index_by(&:id).values_at(*alias_ids).compact if ordered

            aliases.detect(&:icon?)&.primary_classification&.id
          end
        end
      end
    end
  end
end
