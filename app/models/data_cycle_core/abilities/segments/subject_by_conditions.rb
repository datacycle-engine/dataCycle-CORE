# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class SubjectByConditions < Base
        attr_reader :subject, :conditions

        def initialize(subject, **conditions)
          @subject = subject
          @conditions = conditions
        end
      end
    end
  end
end
