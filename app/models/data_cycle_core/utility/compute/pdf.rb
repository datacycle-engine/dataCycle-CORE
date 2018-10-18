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

          def thumbnail_url(pdf)
            DataCycleCore::Pdf.find_by(id: pdf)&.try(:thumbnail_url)
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
