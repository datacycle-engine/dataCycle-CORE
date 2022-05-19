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

          def thumbnail_url(**_args)
            DataCycleCore::Video.find_by(id: computed_parameters.values.first)&.file&.thumb_preview&.url
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
