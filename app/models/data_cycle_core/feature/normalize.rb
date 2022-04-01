# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Normalize < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::Normalize
        end
      end
    end
  end
end
