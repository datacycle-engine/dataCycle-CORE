# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Image
        class << self
          def width(image)
            exif_value(image, ['geometry', 'width'])
          end

          def height(image)
            exif_value(image, ['geometry', 'height'])
          end

          def thumbnail_url(image)
            DataCycleCore::Image.find(image)&.try(:thumbnail_url)
          end

          def exif_value(image_id, path)
            image = DataCycleCore::Image.find(image_id)
            return nil if image.blank? || path.blank?
            image.exif_data.dig(*path)
          end
        end
      end
    end
  end
end
