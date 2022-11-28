# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ClassificationAliasAndChildrenNotExternalAndNotInternal < Base
        attr_reader :subject, :conditions

        def initialize
          @subject = DataCycleCore::ClassificationAlias
          @conditions = { external_source_id: nil, internal: false, sub_classification_alias: { internal: false, external_source_id: nil } }
        end
      end
    end
  end
end
