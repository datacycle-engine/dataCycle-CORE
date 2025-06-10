# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Asset
        class << self
          def proxy_url(**args)
            transformations = args.dig(:virtual_definition, 'virtual', 'transformation')
            name = args[:content].name&.parameterize(separator: '_') || args[:content].id
            if transformations['version'] == 'original'
              content = args[:content]
              if content.respond_to?(:asset) && content.send(:asset).present?
                orig_url = content.send(:asset)&.try(:file)&.try(:url)
              else
                orig_url = content.content_url
              end
              [
                Rails.application.config.asset_host,
                'asset',
                args[:content].id,
                transformations['version'],
                "#{name}#{File.extname(orig_url) if orig_url.present?}"
              ].join('/')
            elsif transformations['version'] == 'dynamic'
              [
                Rails.application.config.asset_host,
                'asset',
                args[:content].id,
                transformations['type'],
                transformations['width'],
                transformations['height'],
                "#{name}.#{transformations['format']}"
              ].join('/')
            else
              [
                Rails.application.config.asset_host,
                'asset',
                args[:content].id,
                transformations['version'],
                "#{name}.#{transformations['format']}"
              ].join('/')
            end
          end

          def imgproxy(virtual_definition:, content:, **_args)
            variant = virtual_definition&.dig('virtual', 'transformation', 'version')
            image_processing = virtual_definition&.dig('virtual', 'processing')
            transform_gravity!(content, image_processing) if image_processing&.key?('gravity')

            DataCycleCore::Feature::ImageProxy.process_image(
              content:,
              variant:,
              image_processing:
            )
          end

          def name(content:, virtual_parameters:, **_args)
            content.try(virtual_parameters&.first)&.name
          end

          def asset_id(content:, **_args)
            content.try(:asset)&.id
          end

          private

          def transform_gravity!(content, image_processing)
            gravity_array = Array.wrap(image_processing['gravity'])
            image_processing['gravity'] = 'sm'

            gravity_array.each do |gravity_key|
              break image_processing['gravity'] = gravity_key unless content&.classification_property_names&.include?(gravity_key)

              gravity = content.try(gravity_key)&.first&.uri&.split('#')&.last

              break image_processing['gravity'] = gravity if gravity.present?
            end

            image_processing
          end
        end
      end
    end
  end
end
