# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ClassificationAliasAndChildrenNotExternalAndNotInternal < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::ClassificationAlias
        end

        def include?(classification_alias, *_args)
          classification_alias.external_source_id.nil? && !classification_alias.internal && classification_alias.sub_classification_alias&.none?(&:internal) && classification_alias.sub_classification_alias&.none?(&:external_source_id)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
