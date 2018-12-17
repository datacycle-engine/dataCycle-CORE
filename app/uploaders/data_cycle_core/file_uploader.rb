# frozen_string_literal: true

module DataCycleCore
  class FileUploader < CommonUploader
    def extension_white_list
      DataCycleCore.file_uploader_whitelist
    end
  end
end
