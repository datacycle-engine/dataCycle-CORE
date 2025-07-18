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

          def preview_image_start_time(computed_parameters:, **_args)
            return if computed_parameters['asset'].blank?

            video = DataCycleCore::Video.find_by(id: computed_parameters['asset'])
            video&.file&.blob&.preview_image&.purge
          end

          def preview_url(computed_parameters:, **_args)
            video = DataCycleCore::Video.find_by(id: computed_parameters.values.first)
            thumb_url = nil

            if video&.file&.attached?
              DataCycleCore::ActiveStorageService.with_current_options do
                thumb_url = video.file.preview({}).processed.url
              end
            end

            thumb_url
          rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError
            nil
          end

          def thumbnail_url(computed_parameters:, **_args)
            video = DataCycleCore::Video.find_by(id: computed_parameters.values.first)
            thumb_url = nil
            if video&.file&.attached?
              begin
                DataCycleCore::ActiveStorageService.with_current_options do
                  thumb_url = video.file.preview(resize_to_limit: [300, 300]).processed.url
                end
              rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError
                return nil
              end
            end

            thumb_url
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
