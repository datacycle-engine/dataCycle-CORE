# frozen_string_literal: true

module DataCycleCore
  module ActiveStorageHelper
    def upload_image(file_name)
      upload_asset(file_name)
    end

    def upload_video(file_name)
      upload_asset(file_name, 'videos')
    end

    def upload_audio(file_name)
      upload_asset(file_name, 'audio')
    end

    def upload_pdf(file_name)
      upload_asset(file_name, 'pdf')
    end

    def upload_text_file(file_name)
      upload_asset(file_name, 'text_file')
    end

    def upload_asset(file_name, type = 'images')
      file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, type, file_name)
      asset = "DataCycleCore::#{type.singularize.camelize}".constantize.new
      asset.file.attach(io: File.open(file_path), filename: file_name)
      asset.creator_id = @current_user.try(:id)
      asset.save

      assert(asset.persisted?)
      assert(asset.valid?)
      assert(asset.file.attached?)

      asset.reload
    end

    def active_storage_url_for(file)
      return if file.blank?

      DataCycleCore::ActiveStorageService.with_current_options do
        file.url
      end
    end
  end
end
