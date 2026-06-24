# frozen_string_literal: true

module DataCycleCore
  class DataCycleFile < Asset
    has_one_attached :file

    cattr_reader :versions, default: {}

    def self.extension_white_list
      DataCycleCore.uploader_validations.dig(:data_cycle_file, :format).presence || []
    end
  end
end
