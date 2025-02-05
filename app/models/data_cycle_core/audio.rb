# frozen_string_literal: true

require 'taglib'

module DataCycleCore
  class Audio < Asset
    has_one_attached :file

    cattr_reader :versions, default: {}
    attr_accessor :remote_file_url
    before_validation :load_file_from_remote_file_url, if: -> { remote_file_url.present? }

    def custom_validators
      DataCycleCore.uploader_validations[self.class.name.demodulize.underscore]&.except(:format)&.presence&.each do |validator, options|
        try("#{validator}_validation", options)
      end
    end

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:audio, :format).presence || ['mp3', 'ogg', 'wav', 'wma', 'mpga']
    end

    private

    def metadata_from_blob
      if attachment_changes['file'].attachable.is_a?(::Hash) && attachment_changes['file'].attachable[:io].present?
        # import from local disc
        path_to_tempfile = attachment_changes['file'].attachable[:io].path
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
