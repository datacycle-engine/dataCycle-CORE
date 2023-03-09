# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class SubjectNotExternal < Base
        attr_reader :subject, :conditions

        def initialize(*subject)
          @subject = Array.wrap(subject).flatten
          @conditions = { external_source_id: nil }
        end
      end
    end
  end
end
