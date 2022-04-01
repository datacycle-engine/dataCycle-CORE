# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Releasable < Base
      class << self
        def content_module
          DataCycleCore::Feature::Content::Releasable
        end

        def data_hash_module
          DataCycleCore::Feature::DataHash::Releasable
        end

        def get_stage(stage = '')
          configuration.dig('classification_names', stage)
        end
      end
    end
  end
end
