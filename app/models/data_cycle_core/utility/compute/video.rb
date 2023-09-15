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
            content&.asset&.file&.blob&.preview_image&.purge
            nil
          end

          def thumbnail_url(computed_parameters:, **_args)
            video = DataCycleCore::Video.find_by(id: computed_parameters.values.first)
            thumb_url = nil
            if video&.file&.attached?
              begin
                ActiveStorage::Current.set(host: Rails.application.config.asset_host) do
                  thumb_url = video.file.preview(resize_to_limit: [300, 300]).processed.url
                end
              rescue ActiveStorage::FileNotFoundError
                return nil
              end
            end

            thumb_url
          end

          def transcode(**args)
            content = args.dig(:content)
            original_value = content.try(args.dig(:key))
            return original_value if original_value.present? && original_value != DataCycleCore::Feature::VideoTranscoding.placeholder

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
