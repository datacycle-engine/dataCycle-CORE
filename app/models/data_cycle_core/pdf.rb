# frozen_string_literal: true

module DataCycleCore
  class Pdf < Asset
    mount_uploader :file, PdfUploader
    process_in_background :file
  end
end
