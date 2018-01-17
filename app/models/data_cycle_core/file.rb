module DataCycleCore
  class File < DataCycleCore::Asset
    mount_uploader :file, FileUploader
    process_in_background :file
  end
end
