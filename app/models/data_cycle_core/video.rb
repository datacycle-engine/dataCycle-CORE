# frozen_string_literal: true

require 'streamio-ffmpeg'

module DataCycleCore
  class Video < Asset
    if DataCycleCore.experimental_features.dig('active_storage', 'enabled')
      has_one_attached :file
    else
      mount_uploader :file, VideoUploader
      process_in_background :file
      validates_integrity_of :file
      after_destroy :remove_directory
      delegate :versions, to: :file
    end

    if DataCycleCore.experimental_features.dig('active_storage', 'enabled')
      def versions
        {}
      end
    end

    def custom_validators
      if DataCycleCore.experimental_features.dig('active_storage', 'enabled')
        DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore)&.except(:format)&.presence&.each do |validator, options|
          try("#{validator}_validation", options)
        end
      else
        DataCycleCore.uploader_validations.dig(file.class.name.underscore.match(/(\w+)_uploader/) { |m| m[1].to_sym })&.except(:format)&.presence&.each do |validator, options|
          try("#{validator}_validation", options)
        end
      end
    end

    def codec_validation(options)
      if DataCycleCore.experimental_features.dig('active_storage', 'enabled')
        if attachment_changes['file'].attachable.is_a?(::Hash) && attachment_changes['file'].attachable.dig(:io).present?
          # import from local disc
          path_to_tempfile = attachment_changes['file'].attachable.dig(:io).path
        else
          path_to_tempfile = attachment_changes['file'].attachable.tempfile.path
        end
      else
        path_to_tempfile = file.file.path
      end

      video = FFMPEG::Movie.new(path_to_tempfile)

      validate_video_codec(video, options)
      validate_audio_codec(video, options)
    end

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:video, :format).presence || ['avi', 'mov', 'mp4', 'mpeg', 'mpg', 'wmv']
    end

    def update_asset_attributes
      return if file.blank?
      if self.class.active_storage_activated?
        self.content_type = file.blob.content_type
        self.file_size = file.blob.byte_size
        self.name ||= file.blob.filename
        begin
          self.metadata = metadata_from_blob
        rescue JSON::GeneratorError
          self.metadata = nil
        end
        self.duplicate_check = file.duplicate_check if file.respond_to?(:duplicate_check)
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
      if attachment_changes['file'].attachable.is_a?(::Hash) && attachment_changes['file'].attachable.dig(:io).present?
        # import from local disc
        path_to_tempfile = attachment_changes['file'].attachable.dig(:io).path
      else
        path_to_tempfile = attachment_changes['file'].attachable.tempfile.path
      end
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
