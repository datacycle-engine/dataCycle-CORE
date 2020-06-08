# frozen_string_literal: true

module DataCycleCore
  class Video < Asset
    mount_uploader :file, VideoUploader
    process_in_background :file

    def codec_validation(options)
      video = FFMPEG::Movie.new(file.file.path)

      errors.add :file, I18n.t('uploader.validation.codec.video', data: options.dig(:video)&.join(', '), locale: DataCycleCore.ui_language) if options.dig(:video)&.exclude?(video.video_codec)
      errors.add :file, I18n.t('uploader.validation.codec.audio', data: options.dig(:audio)&.join(', '), locale: DataCycleCore.ui_language) if options.dig(:audio)&.exclude?(video.audio_codec)
    end
  end
end
