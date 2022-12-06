# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ClassificationTreeLabelAndClassificationAliasesNotExternalAndNotInternal < Base
        attr_reader :subject, :conditions

        def initialize
          @subject = DataCycleCore::ClassificationTreeLabel
          @conditions = { external_source_id: nil, internal: false, classification_aliases: { internal: false, external_source_id: nil } }
        end
      end
    end
  end
end
