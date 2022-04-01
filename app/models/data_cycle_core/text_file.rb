# frozen_string_literal: true

module DataCycleCore
  class TextFile < DataCycleCore::Asset
    has_many :data_links, dependent: :nullify, foreign_key: 'asset_id', inverse_of: :text_file
    has_one_attached :file

    cattr_reader :versions, default: {}
    attr_accessor :remote_file_url
    before_validation :load_file_from_remote_file_url, if: -> { remote_file_url.present? }

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:text_file, :format).presence || ['pdf']
    end
  end
end
