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
            return nil if image.blank?
            DataCycleCore::Image.find_by(id: image)&.try(:thumbnail_url)
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
