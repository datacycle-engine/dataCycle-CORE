# frozen_string_literal: true

module DataCycleCore
  class SrtFile < Asset
    has_one_attached :file

    cattr_reader :versions, default: {}
    attr_accessor :remote_file_url
    before_validation :load_file_from_remote_file_url, if: -> { remote_file_url.present? }

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:srt, :format).presence || ['srt']
    end
  end
end
