# frozen_string_literal: true

module DataCycleCore
  module Feature
    class VideoTranscoding < Base
      class << self
        def process_video(content:, variant:)
          return unless processable?(content: content, variant: variant)
          video_processing = config.dig(variant, 'processing')

          processed_dir = Rails.public_path.join('uploads', 'processed', 'video', content.id)
          FileUtils.mkdir_p(processed_dir)

          filename = video_filename(content, video_processing)
          output_path = File.join(processed_dir, filename)

          movie = nil
          if content.asset.class.active_storage_activated?
            content.asset.file.blob.open do |video|
              movie = FFMPEG::Movie.new(video.path)
              movie.transcode(output_path, video_processing.dig('options'))
            end
          else
            movie = FFMPEG::Movie.new(content.asset.file.file.path)
            movie.transcode(output_path, video_processing.dig('options'))
          end
          # @todo: trigger cache invalidation
          [
            Rails.application.config.asset_host,
            'processed',
            'video',
            content.id,
            filename
          ].join('/')
        end

        def config
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym).dig(:config)
        end

        def placeholder
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym).dig(:placeholder)
        end

        def processable?(content:, variant:)
          enabled? && content.is_a?(DataCycleCore::Thing) && config.include?(variant) && content&.asset.present?
        end

        private

        def video_filename(content, variant)
          filename = content.asset.name
          filename = filename.split('.').size > 1 ? filename.split('.')[0...-1].join : filename
          filename_append = variant.dig('filename_append').present? ? "-#{variant.dig('filename_append')}" : ''
          file_extension = variant.dig('file_ext')
          "#{filename.parameterize(separator: '_')}#{filename_append}.#{file_extension}"
        end
      end
    end
  end
end
