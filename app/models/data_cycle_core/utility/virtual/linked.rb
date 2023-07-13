# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Linked
        class << self
          def parent(content:, **_args)
            content&.related_contents&.limit(1) || DataCycleCore::Thing.none
          end
        end
      end
    end
  end
end
