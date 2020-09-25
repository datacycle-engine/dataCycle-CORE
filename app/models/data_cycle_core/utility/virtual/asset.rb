# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Asset
        class << self
          def proxy_url(**args)
            transformations = args.dig(:virtual_definition, 'virtual', 'transformation')
            if transformations.dig('version') == 'dynamic'
              [
                Rails.application.config.asset_host,
                'asset',
                args.dig(:content).id,
                transformations.dig('type'),
                transformations.dig('width'),
                transformations.dig('height'),
                "#{args.dig(:content).name.parameterize(separator: '_')}.#{transformations.dig('format')}"
              ].join('/')
            else
              [
                Rails.application.config.asset_host,
                'asset',
                args.dig(:content).id,
                transformations.dig('version'),
                "#{args.dig(:content).name.parameterize(separator: '_')}.#{transformations.dig('format')}"
              ].join('/')
            end
          end
        end
      end
    end
  end
end
