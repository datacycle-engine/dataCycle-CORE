# frozen_string_literal: true

module DataCycleCore
  module Feature
    class NamedVersion < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::NamedVersion
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::NamedVersion
        end

        def ability_class
          DataCycleCore::Feature::Abilities::NamedVersion
        end
      end
    end
  end
end
