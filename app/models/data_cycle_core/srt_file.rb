# frozen_string_literal: true

module DataCycleCore
  class SrtFile < Asset
    mount_uploader :file, SrtUploader
    process_in_background :file
  end
end
