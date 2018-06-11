# frozen_string_literal: true

module DataCycleCore
  class Video < Asset
    mount_uploader :file, VideoUploader
    process_in_background :file
  end
end
