module DataCycleCore
  class Image < Asset
    mount_uploader :file, ImageUploader
    process_in_background :file
  end
end
