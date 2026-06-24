# frozen_string_literal: true

module DataCycleCore
  class SrtFile < Asset
    has_one_attached :file

    cattr_reader :versions, default: {}

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:srt, :format).presence || ['srt']
    end
  end
end
