# frozen_string_literal: true

module DataCycleCore
  module Feature
    class GravityEditor < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::GravityEditor
        end
      end
    end
  end
end
