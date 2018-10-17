# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Medium
        class << self
          def thumb_path(*a)
            DataCycleCore::Asset.find_by(id: a.first)&.file&.thumb_preview&.url
          end
        end
      end
    end
  end
end
