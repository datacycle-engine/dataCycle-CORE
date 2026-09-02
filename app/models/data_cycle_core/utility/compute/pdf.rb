# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Pdf
        extend Extensions::AssetPreviewUrlExtension

        class << self
          def width(**args)
            # not implemented
          end

          def height(**args)
            # not implemented
          end

          def thumbnail_url(**args)
            asset_thumbnail_url(asset_class: DataCycleCore::Pdf, **args)
          end

          def preview_url(**args)
            asset_preview_url(asset_class: DataCycleCore::Pdf, **args)
          end

          def exif_value(pdf_id, path)
            pdf = DataCycleCore::Pdf.find_by(id: pdf_id)

            return nil if pdf.blank? || path.blank?

            pdf&.metadata&.dig(*path)
          end

          def extract_content(computed_parameters:, content:, **_args)
            pdf = DataCycleCore::Pdf.find_by(id: asset_ids(computed_parameters:, content:))

            return nil if pdf.blank?

            pdf&.metadata&.dig('content')
          end
        end
      end
    end
  end
end
