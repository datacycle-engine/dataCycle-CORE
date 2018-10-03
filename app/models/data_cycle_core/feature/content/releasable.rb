# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module Releasable
        def release_stage
          try(DataCycleCore::Feature::Releasable.attribute_keys(self).first)&.first
        end
      end
    end
  end
end
