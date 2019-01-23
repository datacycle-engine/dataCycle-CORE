# frozen_string_literal: true

module DataCycleCore
  class TextFile < DataCycleCore::Asset
    has_many :data_links, dependent: :nullify, foreign_key: 'asset_id', inverse_of: :text_file

    mount_uploader :file, TextFileUploader
    process_in_background :file
  end
end
