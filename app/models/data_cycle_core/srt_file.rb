# frozen_string_literal: true

module DataCycleCore
  class SrtFile < Asset
    mount_uploader :file, SrtUploader
    process_in_background :file
    validates_integrity_of :file
    after_destroy :remove_directory
    delegate :versions, to: :file
  end
end
