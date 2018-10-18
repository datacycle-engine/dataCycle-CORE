# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Video
        class << self
          def width(video)
            meta_stream_value(video, ['width'])
          end

          def height(video)
            meta_stream_value(video, ['height'])
          end

          def frame_size(_video)
            # TODO: implement
          end

          def quality(_video)
            # TODO: implement
          end

          def duration(video)
            meta_value(video, ['format', 'duration'])&.to_f
          end

          def thumbnail_url(video)
            DataCycleCore::Video.find_by(id: video)&.try(:thumbnail_url)
          end

          def meta_value(video_id, path)
            video = DataCycleCore::Video.find_by(id: video_id)
            return nil if video.blank? || path.blank?
            video.metadata.dig(*path)
          end

          def meta_stream_value(video_id, path)
            meta_value(video_id, ['streams'])&.first&.dig(*path)
          end
        end
      end
    end
  end
end
