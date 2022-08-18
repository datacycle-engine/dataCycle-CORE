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
            image = DataCycleCore::Image.find_by(id: computed_parameters.values.first)
            thumb_url = nil
            if image.class.active_storage_activated? && image&.file&.attached?
              begin
                ActiveStorage::Current.set(host: Rails.application.config.asset_host) do
                  thumb_url = image.file.variant(resize_to_limit: [300, 300]).processed.url
                end
              rescue ActiveStorage::FileNotFoundError
                # add some logging
                return nil
              end
            else
              thumb_url = image&.file&.thumb_preview&.url
            end
            thumb_url
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
