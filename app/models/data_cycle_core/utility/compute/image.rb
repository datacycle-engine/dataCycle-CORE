# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Image
        class << self
          def width(**args)
            exif_value(args.dig(:computed_parameters)&.first, ['ImageWidth'])&.to_i || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def height(**args)
            exif_value(args.dig(:computed_parameters)&.first, ['ImageHeight'])&.to_i || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def thumbnail_url(**args)
            DataCycleCore::Image.find_by(id: args.dig(:computed_parameters)&.first)&.file&.thumb_preview&.url || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
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
