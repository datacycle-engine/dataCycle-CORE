# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class SubjectNotExternal < Base
        include NotExternalConditions

        attr_reader :subject

        def initialize(*subject)
          @subject = Array.wrap(subject).flatten
        end

        # @return [Hash] see NotExternalConditions for why the shape depends on the subject
        def conditions
          @conditions ||= not_external_conditions
        end
      end
    end
  end
end
