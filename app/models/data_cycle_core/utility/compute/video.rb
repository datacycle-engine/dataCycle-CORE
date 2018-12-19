# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Video
        class << self
          def width(computed_parameters:, key:, data_hash:, content:)
            meta_stream_value(computed_parameters.dig('asset'), ['width'])&.to_i || data_hash.dig(key)
          end

          def height(computed_parameters:, key:, data_hash:, content:)
            meta_stream_value(computed_parameters.dig('asset'), ['height'])&.to_i || data_hash.dig(key)
          end

          def frame_size(computed_parameters:, key:, data_hash:, content:)
            # TODO: implement
          end

          def quality(computed_parameters:, key:, data_hash:, content:)
            # TODO: implement
          end

          def duration(computed_parameters:, key:, data_hash:, content:)
            meta_value(computed_parameters.dig('asset'), ['format', 'duration'])&.to_f || data_hash.dig(key)
          end

          def thumbnail_url(computed_parameters:, key:, data_hash:, content:)
            DataCycleCore::Video.find_by(id: computed_parameters.dig('asset'))&.try(:thumbnail_url) || data_hash.dig(key)
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
