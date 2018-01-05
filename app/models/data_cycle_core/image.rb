module DataCycleCore
  class Image < DataCycleCore::Asset

    mount_uploader :file, ImageUploader
    process_in_background :file

  end
end
