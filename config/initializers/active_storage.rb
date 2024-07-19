# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Rails.application.configure do
    config.active_storage.previewers = [
      DataCycleCore::Storage::Previewer::MuPdfPreviewer,
      DataCycleCore::Storage::Previewer::VideoPreviewer
    ]

    ActiveStorage::Blobs::ProxyController.include DataCycleCore::ErrorHandler
    ActiveStorage::Blobs::ProxyController.prepend DataCycleCore::ActiveStorageProxyControllerExtension
  end
end

ActiveSupport.on_load(:active_storage_blob) { prepend DataCycleCore::ActiveStorageBlobExtension }
