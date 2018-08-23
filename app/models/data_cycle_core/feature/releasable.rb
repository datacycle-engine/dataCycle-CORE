# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Releasable < Base
      # TODO: implement abilities
      class << self
        def get_stage(stage = '')
          configuration.dig('classification_names', stage)
        end
      end
    end
  end
end
