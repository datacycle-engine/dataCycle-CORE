# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class SubjectNotExternalAndNotInternal < Base
        include NotExternalConditions

        attr_reader :subject

        def initialize(*subject)
          @subject = Array.wrap(subject).flatten
        end

        # @return [Hash] see NotExternalConditions for why the external part depends on the subject
        def conditions
          @conditions ||= not_external_conditions.merge(internal: false)
        end
      end
    end
  end
end
