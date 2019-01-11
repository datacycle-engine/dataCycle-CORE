# frozen_string_literal: true

module DataCycleCore
  class DataCycleFile < DataCycleCore::Asset
    mount_uploader :file, FileUploader
    process_in_background :file
  end
end
