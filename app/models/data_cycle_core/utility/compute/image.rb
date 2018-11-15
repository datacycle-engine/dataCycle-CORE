# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Image
        class << self
          def width(image)
            exif_value(image, ['geometry', 'width'])&.to_i
          end

          def height(image)
            exif_value(image, ['geometry', 'height'])&.to_i
          end

          def thumbnail_url(image)
            DataCycleCore::Image.find_by(id: pdf)&.file&.thumb_preview&.url
          end

          def exif_value(image_id, path)
            image = DataCycleCore::Image.find_by(id: image_id)
            return nil if image.blank? || path.blank?
            image.metadata.dig(*path)
          end
        end
      end
    end
  end
end
