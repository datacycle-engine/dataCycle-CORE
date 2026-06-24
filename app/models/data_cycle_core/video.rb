# frozen_string_literal: true

require 'streamio-ffmpeg'

module DataCycleCore
  class Video < Asset
    has_one_attached :file

    cattr_reader :versions, default: { thumb_preview: {} }

    def custom_validators
      DataCycleCore.uploader_validations[self.class.name.demodulize.underscore]&.except(:format)&.presence&.each do |validator, options|
        try("#{validator}_validation", options)
      end
    end

    def codec_validation(options)
      path_to_tempfile = if attachment_changes.present?
                           if attachment_changes['file']&.attachable.is_a?(::Hash) && attachment_changes['file']&.attachable&.dig(:io).present?
                             # import from local disc
                             attachment_changes['file'].attachable[:io].path
                           else
                             attachment_changes['file'].attachable.tempfile.path
                           end
                         else
                           file.service.path_for(file.key)
                         end

      video = FFMPEG::Movie.new(path_to_tempfile)

      validate_video_codec(video, options)
      validate_audio_codec(video, options)
    end

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:video, :format).presence || ['avi', 'mov', 'mp4', 'mpeg', 'mpg', 'wmv']
    end

    def self.content_type_white_list
      super.map { |type| type.gsub('application', 'video') }
    end

    private

    def metadata_from_blob
      path_to_tempfile = if attachment_changes['file'].attachable.is_a?(::Hash) && attachment_changes['file'].attachable[:io].present?
                           # import from local disc
                           attachment_changes['file'].attachable[:io].path
                         else
                           attachment_changes['file'].attachable.tempfile.path
                         end
      movie = FFMPEG::Movie.new(path_to_tempfile)

      return movie.metadata&.to_utf8 if movie.metadata.try(:to_utf8)&.to_json.present?

      nil
    end

    def validate_video_codec(video, options)
      return unless options[:video]&.exclude?(video.video_codec)

      errors.add :file,
                 :invalid,
                 path: 'uploader.validation.codec.video',
                 substitutions: { data: options[:video]&.join(', ') }
    end

    def validate_audio_codec(video, options)
      return unless options[:audio]&.exclude?(video.audio_codec)

      errors.add :file,
                 :invalid,
                 path: 'uploader.validation.codec.audio',
                 substitutions: { data: options[:audio]&.join(', ') }
    end
  end
end
