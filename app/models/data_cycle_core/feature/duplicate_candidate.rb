# frozen_string_literal: true

module DataCycleCore
  module Feature
    class DuplicateCandidate < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::DuplicateCandidate
        end

        def data_hash_module
          DataCycleCore::Feature::DataHash::DuplicateCandidate
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::DuplicateCandidate
        end
      end
    end
  end
end
