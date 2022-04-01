# frozen_string_literal: true

require 'taglib'

module DataCycleCore
  class AudioUploader < CommonUploader
    def extension_white_list
      DataCycleCore.uploader_validations.dig(self.class.name.underscore.match(/(\w+)_uploader/) { |m| m[1].to_sym }, :format).presence || ['mp3', 'ogg', 'wav', 'wma']
    end

    def metadata
      TagLib::FileRef.open(current_path) do |fileref|
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
