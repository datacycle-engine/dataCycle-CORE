# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class SubjectByEnabledFeature < Base
        attr_reader :subject, :feature

        def initialize(subject, feature)
          @feature = feature
          @subject = subject
        end

        def include?(*_args)
          feature.enabled?
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def visible?
          feature.enabled?
        end
      end
    end
  end
end
