# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingByContentType < Base
        attr_reader :subject, :content_types

        def initialize(content_types)
          @content_types = Array.wrap(content_types).map(&:to_s)
          @subject = DataCycleCore::Thing
        end

        def conditions
          { content_type: content_types }
        end
      end
    end
  end
end
