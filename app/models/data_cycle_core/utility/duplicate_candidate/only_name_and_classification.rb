# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      # Pairs contents of the same template that have an identical name and share at least one
      # classification of the configured trees.
      #
      # Sibling of OnlyNameAndLocality for imported contents that carry no address: the tree takes
      # over the role the locality plays there, which keeps same-named contents of different places
      # apart without falling back to NameSimilarity (that one scores similarity * 100, so an equal
      # name alone already reaches 100).
      #
      # Configured per template, next to the module list:
      #
      #   :duplicate_candidate:
      #     :allowed: true
      #     :tree_labels:
      #       - Feratel - Orte
      #     :module:
      #       - OnlyNameAndClassification
      class OnlyNameAndClassification < Base
        PARAMETERS = ['name'].freeze

        class << self
          # The template's classification properties count as parameters too: a shared classification
          # is half the rule, so a change to one has to enqueue the candidate recalculation (see
          # Feature::DataHash::DuplicateCandidate#affected_by_change?).
          def parameters(content: nil, **)
            PARAMETERS + Array.wrap(content&.classification_property_names)
          end

          # The classification half of the rule is untranslated, so only the name half is locale
          # bound (see Base.same_locale_scope). The `distinct` that used to sit on the pluck goes
          # with the locale predicate: the scope now reaches one translation per content, so the
          # pluck can no longer repeat an id.
          #
          # @param content [DataCycleCore::Thing] content to find candidates for
          # @return [Array<Hash>, nil] candidate rows scored 100, nil when the content has no name
          #   in the current locale or no concept of the configured trees
          def duplicates(content:, **)
            return if content.try(:name).blank?

            concept_ids = shared_concept_ids(content)
            return if concept_ids.blank?

            thing_ids = same_locale_scope(content)
              .where("thing_translations.content ->> 'name' = ?", content.name)
              .where(id: DataCycleCore::ConceptContent.with_concept_ids(concept_ids).select(:content_data_id))
              .pluck(:id)

            candidate_rows(thing_ids, score: 100)
          end

          private

          # @return [Array<String>] ids of the content's concepts that belong to a configured tree,
          #   empty when no tree is configured or the content has none of them
          def shared_concept_ids(content)
            tree_labels = Array.wrap(feature.configuration(content)['tree_labels']).compact_blank
            return [] if tree_labels.blank?

            DataCycleCore::ConceptContent
              .with_content(content.id)
              .with_concept_ids(DataCycleCore::Concept.for_tree(tree_labels).select(:id))
              .pluck(:concept_id)
          end
        end
      end
    end
  end
end
