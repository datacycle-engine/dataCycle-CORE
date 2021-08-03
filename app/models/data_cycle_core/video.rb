# frozen_string_literal: true

module DataCycleCore
  class Video < Asset
    mount_uploader :file, VideoUploader
    process_in_background :file

    def codec_validation(options)
      video = FFMPEG::Movie.new(file.file.path)

      if options.dig(:video)&.exclude?(video.video_codec)
        errors.add :file, {
          path: 'uploader.validation.codec.video',
          substitutions: { data: options.dig(:video)&.join(', ') }
        }
      end
      if options.dig(:audio)&.exclude?(video.audio_codec)
        errors.add :file, {
          path: 'uploader.validation.codec.audio',
          substitutions: { data: options.dig(:audio)&.join(', ') }
        }
      end
    end
  end
end
