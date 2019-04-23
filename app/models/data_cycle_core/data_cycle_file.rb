# frozen_string_literal: true

module DataCycleCore
  class DataCycleFile < Asset
    mount_uploader :file, DataCycleFileUploader
    process_in_background :file
  end
end
