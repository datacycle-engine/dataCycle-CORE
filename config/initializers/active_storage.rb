# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Rails.application.configure do
    config.active_storage.previewers = [
      ActiveStorage::Previewer::PopplerPDFPreviewer,
      ActiveStorage::Previewer::MuPDFPreviewer,
      DataCycleCore::Storage::Previewer::VideoPreviewer
    ]

    ActiveStorage::Blobs::ProxyController.include DataCycleCore::ErrorHandler
    ActiveStorage::Blobs::ProxyController.prepend DataCycleCore::ActiveStorageProxyControllerExtension
    ActiveStorage::Previewer::MuPDFPreviewer.prepend DataCycleCore::ActiveStorageMuPreviewerExtension
  end
end

ActiveSupport.on_load(:active_storage_blob) { prepend DataCycleCore::ActiveStorageBlobExtension }
