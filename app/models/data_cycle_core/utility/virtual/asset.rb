# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Asset
        class << self
          def proxy_url(**args)
            transformations = args.dig(:virtual_definition, 'virtual', 'transformation')
            name = args.dig(:content).name&.parameterize(separator: '_') || args.dig(:content).id
            if transformations.dig('version') == 'original'
              content = args.dig(:content)
              if content.respond_to?(:asset) && content.send(:asset).present?
                orig_url = content.send(:asset)&.try(:file)&.try(:url)
              else
                orig_url = content.content_url
              end
              [
                Rails.application.config.asset_host,
                'asset',
                args.dig(:content).id,
                transformations.dig('version'),
                "#{name}#{orig_url.present? ? File.extname(orig_url) : ''}"
              ].join('/')
            elsif transformations.dig('version') == 'dynamic'
              [
                Rails.application.config.asset_host,
                'asset',
                args.dig(:content).id,
                transformations.dig('type'),
                transformations.dig('width'),
                transformations.dig('height'),
                "#{name}.#{transformations.dig('format')}"
              ].join('/')
            else
              [
                Rails.application.config.asset_host,
                'asset',
                args.dig(:content).id,
                transformations.dig('version'),
                "#{name}.#{transformations.dig('format')}"
              ].join('/')
            end
          end

          def imgproxy(**args)
            variant = args.dig(:virtual_definition, 'virtual', 'transformation', 'version')
            image_processing = args.dig(:virtual_definition, 'virtual', 'processing')
            content = args.dig(:content)

            DataCycleCore::Feature::ImageProxy.process_image(
              content: content,
              variant: variant,
              image_processing: image_processing
            )
          end
        end
      end
    end
  end
end
