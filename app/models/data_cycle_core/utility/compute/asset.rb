# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Asset
        def self.file_size(**args)
          DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:file_size)&.to_i || args.dig(:data_hash, args.dig(:key))
        end

        def self.file_format(**args)
          DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:content_type) || args.dig(:data_hash, args.dig(:key))
        end

        def self.content_url(**args)
          DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:file)&.try(:url) || args.dig(:data_hash, args.dig(:key))
        end
      end
    end
  end
end
