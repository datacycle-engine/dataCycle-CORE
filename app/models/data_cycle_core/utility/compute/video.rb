# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Video
        class << self
          def width(computed_parameters:, **_args)
            meta_stream_value(computed_parameters.values.first, ['width'])&.to_i
          end

          def height(computed_parameters:, **_args)
            meta_stream_value(computed_parameters.values.first, ['height'])&.to_i
          end

          def frame_size(**args)
            # not implemented
          end

          def quality(**args)
            # not implemented
          end

          def duration(computed_parameters:, **_args)
            meta_value(computed_parameters.values.first, ['format', 'duration'])&.to_f
          end

          def preview_image_start_time(content:, **_args)
            content&.asset&.file&.blob&.preview_image&.purge if DataCycleCore.experimental_features.dig('active_storage', 'enabled')
            nil
          end

          def thumbnail_url(computed_parameters:, **_args)
            video = DataCycleCore::Video.find_by(id: computed_parameters.values.first)
            video&.file&.thumb_preview&.url
          end

          def transcode(**args)
            content = args.dig(:content)
            original_value = content.try(args.dig(:key))
            return original_value if original_value.present? && original_value != DataCycleCore::Feature::VideoTranscoding.placeholder
            # could be used for custom processing instructions via data definition
            # video_processing = args.dig(:computed_definition, 'compute', 'processing')

            asset = args.dig(:computed_parameters)&.first || args.dig(:content).try(:asset)
            return if asset.blank?

            DataCycleCore::VideoTranscodingJob.perform_later(content.id, args.dig(:key))
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
