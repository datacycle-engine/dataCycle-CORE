# frozen_string_literal: true

module DataCycleCore
  class MissingAssetController < ActiveStorage::BaseController
    include DataCycleCore::ErrorHandler
    include DataCycleCore::ActiveStorageStreaming
    include ActiveStorage::SetHeaders
    include ActiveStorage::DisableSession

    protect_from_forgery with: :exception

    def show
      asset_class = "data_cycle_core/#{permitted_params[:klass]}".classify.safe_constantize
      raise ActiveRecord::RecordNotFound if asset_class.nil?

      @asset = asset_class.find(permitted_params[:id])
      filename = nil
      content_type = nil

      if permitted_params[:transformation]&.values.present?
        @asset_version = @asset.try(:dynamic, permitted_params[:transformation])
        @asset_path = @asset_version&.blob&.attachments&.first&.record&.file&.service&.path_for(@asset_version.key)

        content_type = @asset_version.variation.content_type
        filename = @asset_version.blob.filename.base + '.' + MiniMime.lookup_by_content_type(content_type)&.extension
      elsif permitted_params[:version] == 'original'
        @asset_version = @asset.try(permitted_params[:version])
        @asset_path = @asset_version&.service&.path_for(@asset_version.key)

        content_type = @asset_version.content_type
        filename = @asset_version.filename.to_s
      else
        @asset_version = @asset.try(permitted_params[:version], { recreate: true })
        @asset_path = @asset_version&.blob&.attachments&.first&.record&.file&.service&.path_for(@asset_version.key)

        content_type = @asset_version.variation.content_type
        filename = @asset_version.blob.filename.to_s
      end
      raise ActiveRecord::RecordNotFound if @asset_path.blank?

      headers['ETag'] = %("#{File.mtime(@asset_path)}-#{@asset_version.try(:size)}")
      headers['Last-Modified'] = File.mtime(@asset_path).httpdate
      headers.delete 'X-Frame-Options'

      send_file @asset_path, disposition: 'inline', filename:, type: content_type
    rescue StandardError => e
      not_found(e)
    end

    def show_blob
      @blob = ActiveStorage::Blob.find(permitted_params[:id])

      raise ActiveRecord::RecordNotFound if @blob.nil?

      if request.headers['Range'].present?
        send_blob_byte_range_data @blob, request.headers['Range']
      else
        http_cache_forever public: true do
          set_content_headers_from @blob
          stream @blob
        end
      end
    end

    def processed
      id = permitted_params[:id]
      processed_asset_path = Rails.root.join('public/uploads' + request.path)

      @asset = DataCycleCore::Thing.find(id)&.try(:asset)

      raise ActiveRecord::RecordNotFound unless @asset.file.attached?

      file_status, file_headers, file_body = Rack::File.new(nil).serving(request, processed_asset_path)
      response.status = file_status
      response.headers.merge!(file_headers)
      self.response_body = file_body
    rescue StandardError => e
      not_found(e)
    end

    private

    def permitted_params
      params.permit(:klass, :klass_namespace, :id, :version, :file, transformation: [:format, :width, :height])
    end
  end
end
