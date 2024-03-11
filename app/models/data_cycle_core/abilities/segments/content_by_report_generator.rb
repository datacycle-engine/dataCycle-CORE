# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ContentByReportGenerator < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::Thing
        end

        def include?(content)
          DataCycleCore::Feature::ReportGenerator.allowed?(content)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def visible?
          DataCycleCore::Feature::ReportGenerator.enabled?
        end
      end
    end
  end
end
