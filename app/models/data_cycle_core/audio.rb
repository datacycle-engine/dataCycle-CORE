# frozen_string_literal: true

module DataCycleCore
  class Audio < Asset
    mount_uploader :file, AudioUploader
    process_in_background :file
  end
end
