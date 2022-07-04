# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class SubjectNotInternal < Base
        attr_reader :subject, :conditions

        def initialize(subject)
          @subject = subject
          @conditions = { internal: false }
        end
      end
    end
  end
end
