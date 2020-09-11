# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Video
        class << self
          def width(**args)
            meta_stream_value(args.dig(:computed_parameters)&.first, ['width'])&.to_i || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def height(**args)
            meta_stream_value(args.dig(:computed_parameters)&.first, ['height'])&.to_i || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def frame_size(**args)
            args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def quality(**args)
            args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def duration(**args)
            meta_value(args.dig(:computed_parameters)&.first, ['format', 'duration'])&.to_f || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
          end

          def thumbnail_url(**args)
            DataCycleCore::Video.find_by(id: args.dig(:computed_parameters)&.first)&.file&.thumb_preview&.url || args.dig(:data_hash, args.dig(:key)) || args.dig(:content).try(args.dig(:key))
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
