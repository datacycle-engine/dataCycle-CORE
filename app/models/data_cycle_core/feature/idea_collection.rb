# frozen_string_literal: true

module DataCycleCore
  module Feature
    class IdeaCollection < Base
      class << self
        def template(content = nil)
          configuration(content).dig('template')
        end

        def life_cycle_stage(content = nil)
          configuration(content).dig('life_cycle_stage')
        end
      end
    end
  end
end
