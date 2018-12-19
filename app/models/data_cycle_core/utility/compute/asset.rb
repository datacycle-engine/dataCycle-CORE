# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Asset
        def self.file_size(computed_parameters:, key:, data_hash:, content:)
          DataCycleCore::Asset.find_by(id: computed_parameters.dig('asset'))&.try(:file_size)&.to_i || data_hash.dig(key)
        end

        def self.file_format(computed_parameters:, key:, data_hash:, content:)
          DataCycleCore::Asset.find_by(id: computed_parameters.dig('asset'))&.try(:content_type) || data_hash.dig(key)
        end

        def self.content_url(computed_parameters:, key:, data_hash:, content:)
          DataCycleCore::Asset.find_by(id: computed_parameters.dig('asset'))&.try(:file)&.try(:url) || data_hash.dig(key)
        end
      end
    end
  end
end
