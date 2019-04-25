# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Pdf
        class << self
          def width(**args)
            args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def height(**args)
            args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def thumbnail_url(**args)
            DataCycleCore::Pdf.find_by(id: args.dig(:computed_parameters)&.first)&.file&.thumb_preview&.url || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def exif_value(pdf_id, path)
            pdf = DataCycleCore::Pdf.find_by(id: pdf_id)
            return nil if pdf.blank? || path.blank?
            pdf&.metadata&.dig(*path)
          end

          def extract_content(**args)
            pdf = DataCycleCore::Pdf.find_by(id: args.dig(:computed_parameters)&.first)
            return nil if pdf.blank?
            pdf&.metadata&.dig('content')
          end
        end
      end
    end
  end
end
