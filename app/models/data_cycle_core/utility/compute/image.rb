# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Image
        class << self
          def width(computed_parameters:, **_args)
            exif_value(computed_parameters.values.first, ['ImageWidth'])&.to_i
          end

          def height(computed_parameters:, **_args)
            exif_value(computed_parameters.values.first, ['ImageHeight'])&.to_i
          end

          def thumbnail_url(computed_parameters:, **_args)
            ActiveStorage::Current.set(host: Rails.application.config.asset_host) do
              DataCycleCore::Image.find_by(id: computed_parameters.values.first)&.thumb_preview&.url
            end
          end

          def exif_value(image_id, path)
            image = DataCycleCore::Image.find_by(id: image_id)
            return nil if image.blank? || path.blank?
            image&.metadata&.dig(*path)
          end
        end
      end
    end
  end
end
