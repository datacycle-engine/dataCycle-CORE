# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Asset
        def self.file_size(asset)
          DataCycleCore::Asset.find_by(id: asset)&.try(:file_size)&.to_i
        end

        def self.file_format(asset)
          DataCycleCore::Asset.find_by(id: asset)&.try(:content_type)
        end

        def self.content_url(asset)
          DataCycleCore::Asset.find_by(id: asset)&.try(:file)&.try(:url)
        end
      end
    end
  end
end
