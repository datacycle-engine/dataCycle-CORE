# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Pdf
        class << self
          def width(pdf)
            # TODO: implement
          end

          def height(pdf)
            # TODO: implement
          end

          def thumbnail_url(computed_parameters:, key:, data_hash:, content:)
            DataCycleCore::Pdf.find_by(id: computed_parameters.dig('asset'))&.file&.thumb_preview&.url || data_hash.dig(key)
          end

          def exif_value(pdf_id, path)
            pdf = DataCycleCore::Pdf.find_by(id: pdf_id)
            return nil if pdf.blank? || path.blank?
            pdf.metadata.dig(*path)
          end
        end
      end
    end
  end
end
