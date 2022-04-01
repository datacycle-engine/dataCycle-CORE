# frozen_string_literal: true

module DataCycleCore
  module Feature
    class DuplicateContent < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::DuplicateContent
        end
      end
    end
  end
end
