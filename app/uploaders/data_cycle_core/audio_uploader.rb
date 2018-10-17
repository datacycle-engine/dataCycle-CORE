# frozen_string_literal: true

require 'taglib'

module DataCycleCore
  class AudioUploader < CommonUploader
    def exif_data
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
              length: properties.length,
              sample_rate: properties.sample_rate
            }
          }
        end
      end
    end
  end
end
