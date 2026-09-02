# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Video
        extend Extensions::AssetPreviewUrlExtension

        class << self
          def width(computed_parameters:, content:, **_args)
            meta_stream_value(asset_ids(computed_parameters:, content:), ['width'])&.to_i
          end

          def height(computed_parameters:, content:, **_args)
            meta_stream_value(asset_ids(computed_parameters:, content:), ['height'])&.to_i
          end

          def frame_size(**args)
            # not implemented
          end

          def quality(**args)
            # not implemented
          end

          def duration(computed_parameters:, content:, **_args)
            meta_value(asset_ids(computed_parameters:, content:), ['format', 'duration'])&.to_f
          end

          def preview_image_start_time(computed_parameters:, **_args)
            return if computed_parameters['asset'].blank?

            video = DataCycleCore::Video.find_by(id: computed_parameters['asset'])
            video&.file&.blob&.preview_image&.purge
          end

          def preview_url(**args)
            asset_preview_url(asset_class: DataCycleCore::Video, **args)
          end

          def thumbnail_url(**args)
            asset_thumbnail_url(asset_class: DataCycleCore::Video, **args)
          end

          def transcode(**args)
            content = args[:content]
            original_value = content.try(args[:key])
            return original_value if original_value.present? && original_value != DataCycleCore::Feature::VideoTranscoding.placeholder

            asset = args[:computed_parameters]&.first || args[:content].try(:asset)
            return if asset.blank?

            DataCycleCore::VideoTranscodingJob.perform_later(content.id, args[:key])
            DataCycleCore::Feature::VideoTranscoding.placeholder
          end

          def meta_value(video_id, path)
            video = DataCycleCore::Video.find_by(id: video_id)

            return nil if video.blank? || path.blank?

            video&.metadata&.dig(*path)
          end

          def meta_stream_value(video_id, path)
            meta_value(video_id, ['streams'])&.first&.dig(*path)
          end
        end
      end
    end
  end
end
