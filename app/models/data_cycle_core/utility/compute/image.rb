# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Image
        class << self
          def width(computed_parameters:, key:, data_hash:, content:)
            exif_value(computed_parameters.dig('asset'), ['geometry', 'width'])&.to_i || data_hash.dig(key)
          end

          def height(computed_parameters:, key:, data_hash:, content:)
            exif_value(computed_parameters.dig('asset'), ['geometry', 'height'])&.to_i || data_hash.dig(key)
          end

          def thumbnail_url(computed_parameters:, key:, data_hash:, content:)
            DataCycleCore::Image.find_by(id: computed_parameters.dig('asset'))&.file&.thumb_preview&.url || data_hash.dig(key)
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
