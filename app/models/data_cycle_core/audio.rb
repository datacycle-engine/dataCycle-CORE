# frozen_string_literal: true

require 'taglib'

module DataCycleCore
  class Audio < Asset
    if active_storage_activated?
      has_one_attached :file

      cattr_reader :versions, default: {}
      attr_accessor :remote_file_url
      before_validation :load_file_from_remote_file_url, if: -> { remote_file_url.present? }
    else
      mount_uploader :file, AudioUploader
      process_in_background :file
      validates_integrity_of :file
      after_destroy :remove_directory
      delegate :versions, to: :file
    end

    def custom_validators
      if self.class.active_storage_activated?
        DataCycleCore.uploader_validations.dig(self.class.name.demodulize.underscore)&.except(:format)&.presence&.each do |validator, options|
          try("#{validator}_validation", options)
        end
      else
        DataCycleCore.uploader_validations.dig(file.class.name.underscore.match(/(\w+)_uploader/) { |m| m[1].to_sym })&.except(:format)&.presence&.each do |validator, options|
          try("#{validator}_validation", options)
        end
      end
    end

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:audio, :format).presence || ['mp3', 'ogg', 'wav', 'wma', 'mpga']
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
      TagLib::FileRef.open(path_to_tempfile) do |fileref|
        unless fileref.null?
          tag = fileref.tag
          properties = fileref.audio_properties
          return {
            tag: {
              album: tag.album,
              artist: tag.artist,
              comment: tag.comment,
              genre: tag.genre,
              title: tag.title,
              track: tag.track,
              year: tag.year
            },
            audio_properties: {
              bitrate: properties.bitrate,
              channels: properties.channels,
              length: properties.length_in_seconds,
              sample_rate: properties.sample_rate
            }
          }
        end
      end
    end
  end
end
