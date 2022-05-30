# frozen_string_literal: true

require 'streamio-ffmpeg'

module DataCycleCore
  class Video < Asset
    # if active_storage_activated
    has_one_attached :file
    # else
    #   mount_uploader :file, VideoUploader
    #   process_in_background :file
    # end
    # has_one_attached :file_new

    def codec_validation(options)
      video = FFMPEG::Movie.new(file.file.path)

      validate_video_codec(video, options)
      validate_audio_codec(video, options)
    end

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:video, :format).presence || ['avi', 'mov', 'mp4', 'mpeg', 'mpg', 'wmv']
    end

    def new_thumb(**options)
      file.blob&.preview_image&.purge
      # video_options = { start: 3 }
      # binding.pry
      file.preview(**options).processed.url
    end

    def update_asset_attributes
      return if file.blank?
      if active_storage_activated
        self.content_type = file.blob.content_type
        self.file_size = file.blob.byte_size
        self.name ||= file.blob.filename
        begin
          self.metadata = metadata_from_blob
        rescue JSON::GeneratorError
          self.metadata = nil
        end
      else
        self.content_type = file.file.content_type
        self.file_size = file.file.size
        self.name ||= file.file.filename
        begin
          self.metadata = file.metadata&.to_utf8 if file.respond_to?(:metadata) && file.metadata.try(:to_utf8)&.to_json.present?
        rescue JSON::GeneratorError
          self.metadata = nil
        end
      end
      self.duplicate_check = file.duplicate_check if file.respond_to?(:duplicate_check)
    end

    private

    def metadata_from_blob
      path_to_tempfile = attachment_changes['file'].attachable.tempfile.path
      movie = FFMPEG::Movie.new(path_to_tempfile)

      return movie.metadata&.to_utf8 if movie.metadata.try(:to_utf8)&.to_json.present?
      nil
    end

    def validate_video_codec(video, options)
      return unless options.dig(:video)&.exclude?(video.video_codec)

      errors.add :file, {
        path: 'uploader.validation.codec.video',
        substitutions: { data: options.dig(:video)&.join(', ') }
      }
    end

    def validate_audio_codec(video, options)
      return unless options.dig(:audio)&.exclude?(video.audio_codec)

      errors.add :file, {
        path: 'uploader.validation.codec.audio',
        substitutions: { data: options.dig(:audio)&.join(', ') }
      }
    end
  end
end
