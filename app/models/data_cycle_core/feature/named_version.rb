# frozen_string_literal: true

module DataCycleCore
  module Feature
    class NamedVersion < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::NamedVersion
        end
      end
    end
  end
end
