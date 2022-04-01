# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Asset
        def self.file_name(**args)
          DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:name)&.to_s || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
        end

        def self.file_size(**args)
          DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:file_size)&.to_i || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
        end

        def self.file_format(**args)
          DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:content_type) || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
        end

        def self.content_url(**args)
          DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:file)&.try(:url) || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
        end

        def self.asset_url_with_transformation(**args)
          asset = DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)
          asset.try(args.dig(:computed_definition, 'compute', 'version') || 'original')&.url(args.dig(:computed_definition, 'compute', 'transformation')) || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
        end
      end
    end
  end
end
