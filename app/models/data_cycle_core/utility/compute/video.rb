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

          def preview_url(computed_parameters:, content:, **args)
            thumb_url = thumbnail_image_url(computed_parameters:, content:, **args)
            return thumb_url if thumb_url.present?

            video = DataCycleCore::Video.find_by(id: computed_parameters.values_at(*content.asset_property_names))

            if video&.file&.attached?
              DataCycleCore::ActiveStorageService.with_current_options do
                thumb_url = video.file.preview({}).processed.url
              end
            end

            thumb_url
          rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError
            nil
          end

          def thumbnail_url(computed_parameters:, content:, **args)
            thumb_url = thumbnail_image_url(computed_parameters:, content:, **args)
            return thumb_url if thumb_url.present?

            video = DataCycleCore::Video.find_by(id: computed_parameters.values_at(*content.asset_property_names))

            if video&.file&.attached?
              DataCycleCore::ActiveStorageService.with_current_options do
                thumb_url = video.file.preview(resize_to_limit: [300, 300]).processed.url
              end
            end

            thumb_url
          rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError
            nil
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

          private

          def thumbnail_image_url(computed_parameters:, content:, **args)
            thumbnail_image_params = computed_parameters.except(*content.asset_property_names)
            return if thumbnail_image_params.blank?

            thumb_url = Common.attribute_value_from_first_linked(computed_parameters: thumbnail_image_params, content:, **args)
            thumb_url.presence
          end
        end
      end
    end
  end
end
