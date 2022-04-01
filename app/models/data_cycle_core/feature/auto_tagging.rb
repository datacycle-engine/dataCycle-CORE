# frozen_string_literal: true

module DataCycleCore
  module Feature
    class AutoTagging < Base
      class << self
        def data_hash_module
          DataCycleCore::Feature::DataHash::AutoTagging
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::AutoTagging
        end
      end
    end
  end
end
