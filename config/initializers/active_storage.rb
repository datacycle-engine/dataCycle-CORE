# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Rails.application.configure do
    config.active_storage.previewers = [
      ActiveStorage::Previewer::PopplerPDFPreviewer,
      ActiveStorage::Previewer::MuPDFPreviewer,
      DataCycleCore::Storage::Previewer::VideoPreviewer
    ]
    ActiveStorage::Blobs::ProxyController.include DataCycleCore::ErrorHandler
  end
end
