# frozen_string_literal: true

module DataCycleCore
  module Feature
    class ImageEditor < Base
      class << self
        def file_name(content)
          file_name_segments = content&.asset&.name&.split('.')
          file_name_segments&.[](0...-1)&.join('.').to_s
        end

        def file_mime_type(content)
          content&.asset&.content_type
        end

        def file_url(content)
          return content&.asset&.file&.url if web_safe_mime_type?(content&.asset&.content_type)
          if DataCycleCore::Feature::ImageProxy.enabled?
            return DataCycleCore::Feature::ImageProxy.process_image(
              content:,
              variant: 'dynamic',
              image_processing: {
                'resize_type' => 'fit',
                'width' => 2048,
                'height' => 2048,
                'enlarge' => 0,
                'gravity' => 'ce',
                'format' => 'png'
              }
            )
          end
          content.asset_web_url
        end

        def web_safe_mime_type?(type)
          DataCycleCore::Image::WEB_SAVE_MIME_TYPES.include?(type)
        end

        def crop_options
          configuration[:custom_crop_options] || []
        end
      end
    end
  end
end
