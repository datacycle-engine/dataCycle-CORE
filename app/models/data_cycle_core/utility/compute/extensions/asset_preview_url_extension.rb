# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Extensions
        # Preview and thumbnail URLs for asset backed media templates (Video, PDF, …).
        # A linked preview image always wins, the URL generated from the asset itself
        # (the video still / the rendered first PDF page) is only the fallback.
        #
        # Linked candidates are the compute parameters that point at a linked property of
        # the template; the first one with a value wins, in parameter order. Without such
        # a parameter the behaviour is unchanged — the URL is always generated from the asset.
        #
        # Example (#50159 — thumbnailUrl of a PDF points at the linked "Vorschaubild"):
        #   :compute:
        #     :module: Pdf
        #     :method: thumbnail_url
        #     :parameters:
        #       # with image_proxy enabled the image exposes its virtual_thumbnail_url as
        #       # thumbnailUrl in the api, so prefer that one over the raw active storage
        #       # variant (same precedence as the COALESCE in Geo::BaseRenderer)
        #       - thumbnail_image.virtual_thumbnail_url
        #       - thumbnail_image.thumbnail_url
        #       - asset # fallback: preview rendered from the pdf
        module AssetPreviewUrlExtension
          THUMBNAIL_VARIATION = { resize_to_limit: [300, 300] }.freeze

          private

          def asset_thumbnail_url(**args)
            asset_preview_url(variation: THUMBNAIL_VARIATION, **args)
          end

          def asset_preview_url(asset_class:, computed_parameters:, content:, variation: {}, **args)
            linked_url = linked_preview_url(computed_parameters:, content:, **args)
            return linked_url if linked_url.present?

            asset = asset_class.find_by(id: asset_ids(computed_parameters:, content:))
            return unless asset&.file&.attached?

            DataCycleCore::ActiveStorageService.with_current_options do
              asset.file.preview(variation).processed.url
            end
          rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError
            # @todo: add some logging
            nil
          end

          def asset_ids(computed_parameters:, content:)
            computed_parameters.values_at(*content.asset_property_names)
          end

          def linked_preview_url(computed_parameters:, content:, **args)
            linked_parameters = computed_parameters.slice(*content.linked_property_names)
            return if linked_parameters.blank?

            Common.attribute_value_from_first_linked(computed_parameters: linked_parameters, content:, **args).presence
          end
        end
      end
    end
  end
end
