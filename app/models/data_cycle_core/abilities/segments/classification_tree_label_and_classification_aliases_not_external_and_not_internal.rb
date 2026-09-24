# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      # The subject is DataCycleCore::ConceptScheme; the class name outlived the model for the
      # reason given in classification_alias_and_children_not_external_and_not_internal.rb - the
      # same four projects name this segment by class in their own role definitions.
      class ClassificationTreeLabelAndClassificationAliasesNotExternalAndNotInternal < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::ConceptScheme
        end

        def include?(concept_scheme, *_args)
          concept_scheme.external_system_id.nil? && !concept_scheme.internal && concept_scheme.concepts&.none?(&:internal) && concept_scheme.concepts.none?(&:external_system_id)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
