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

          # @param content [DataCycleCore::Thing] content to find candidates for
          # @return [Array<Hash>, nil] candidate rows scored 100, nil when the content has no name
          #   or no classification of the configured trees
          def duplicates(content:, **)
            return if content.try(:name).blank?

            classification_ids = shared_classification_ids(content)
            return if classification_ids.blank?

            DataCycleCore::Thing
              .joins(:translations)
              .where(template_name: content.template_name)
              .where("thing_translations.content ->> 'name' = ?", content.name)
              .where(id: DataCycleCore::ClassificationContent.with_classification_ids(classification_ids).select(:content_data_id))
              .where.not(id: content.id)
              .distinct
              .pluck(:id)
              .map { |d| { thing_duplicate_id: d, method: identifier, score: 100 } }
          end

          private

          # @return [Array<String>] ids of the content's classifications that belong to a configured
          #   tree, empty when no tree is configured or the content has none of them
          def shared_classification_ids(content)
            tree_labels = Array.wrap(feature.configuration(content)['tree_labels']).compact_blank
            return [] if tree_labels.blank?

            DataCycleCore::ClassificationContent
              .with_content(content.id)
              .with_classification_ids(DataCycleCore::Classification.for_tree(tree_labels).select(:id))
              .pluck(:classification_id)
          end
        end
      end
    end
  end
end
