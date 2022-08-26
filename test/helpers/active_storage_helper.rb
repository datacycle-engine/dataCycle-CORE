# frozen_string_literal: true

module DataCycleCore
  module ActiveStorageHelper
    def upload_image(file_name)
      upload_asset(file_name)
    end

    def upload_video(file_name)
      upload_asset(file_name, 'videos')
    end

    def upload_pdf(file_name)
      upload_asset(file_name, 'pdf')
    end

    def upload_asset(file_name, type = 'images')
      file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, type, file_name)

      asset = "DataCycleCore::#{type.singularize.camelize}".constantize.new
      asset.file.attach(io: File.open(file_path), filename: file_name)
      asset.save

      assert(asset.persisted?)
      assert(asset.valid?)
      assert(asset.file.attached?)

      asset.reload
    end

    def active_storage_url_for(file)
      return unless file.present?
      ActiveStorage::Current.set(host: Rails.application.config.asset_host) do
        file.url
      end
    end
  end
end
