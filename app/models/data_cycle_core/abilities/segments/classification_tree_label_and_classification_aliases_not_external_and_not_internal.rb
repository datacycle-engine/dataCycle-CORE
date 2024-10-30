# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ClassificationTreeLabelAndClassificationAliasesNotExternalAndNotInternal < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::ClassificationTreeLabel
        end

        def include?(classification_tree_label, *_args)
          classification_tree_label.external_source_id.nil? && !classification_tree_label.internal && classification_tree_label.classification_aliases&.none?(&:internal) && classification_tree_label.classification_aliases.none?(&:external_source_id)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
