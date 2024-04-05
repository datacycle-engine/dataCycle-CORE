# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Pdf
        class << self
          def width(**args)
            # not implemented
          end

          def height(**args)
            # not implemented
          end

          def thumbnail_url(computed_parameters:, **_args)
            pdf = DataCycleCore::Pdf.find_by(id: computed_parameters.values.first)
            thumb_url = nil
            if pdf&.file&.attached?
              begin
                ActiveStorage::Current.set(host: Rails.application.config.asset_host) do
                  thumb_url = pdf.file.preview(resize_to_limit: [300, 300]).processed.url
                end
              rescue ActiveStorage::FileNotFoundError
                # @todo: add some logging
                return nil
              end
            end
            thumb_url
          end

          def preview_url(computed_parameters:, **_args)
            pdf = DataCycleCore::Pdf.find_by(id: computed_parameters.values.first)
            preview_url = nil
            if pdf&.file&.attached?
              begin
                ActiveStorage::Current.set(host: Rails.application.config.asset_host) do
                  preview_url = pdf.file.preview(resize_to_limit: [1920, 1080]).processed.url
                end
              rescue ActiveStorage::FileNotFoundError
                # @todo: add some logging
                return nil
              end
            end
            preview_url
          end

          def exif_value(pdf_id, path)
            pdf = DataCycleCore::Pdf.find_by(id: pdf_id)

            return nil if pdf.blank? || path.blank?

            pdf&.metadata&.dig(*path)
          end

          def extract_content(computed_parameters:, **_args)
            pdf = DataCycleCore::Pdf.find_by(id: computed_parameters.values.first)

            return nil if pdf.blank?

            pdf&.metadata&.dig('content')
          end
        end
      end
    end
  end
end
