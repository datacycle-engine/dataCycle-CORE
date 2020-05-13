# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Asset
        def self.file_name(**args)
          args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key)) || DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:name)&.to_s
        end

        def self.file_size(**args)
          args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key)) || DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:file_size)&.to_i
        end

        def self.file_format(**args)
          args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key)) || DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:content_type)
        end

        def self.content_url(**args)
          args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key)) || DataCycleCore::Asset.find_by(id: args.dig(:computed_parameters)&.first)&.try(:file)&.try(:url)
        end
      end
    end
  end
end
