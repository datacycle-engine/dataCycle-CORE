# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  Rails.application.configure do
    config.active_storage.previewers = [
      DataCycleCore::Storage::Previewer::MuPdfPreviewer,
      DataCycleCore::Storage::Previewer::VideoPreviewer
    ]

    ActiveStorage::Blobs::ProxyController.include DataCycleCore::ErrorHandler
  end
end
