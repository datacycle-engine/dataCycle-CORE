# frozen_string_literal: true

module DataCycleCore
  class MissingAssetController < ApplicationController
    include DataCycleCore::ErrorHandler
    protect_from_forgery with: :exception

    def show
      @asset = "data_cycle_core/#{permitted_params[:klass]}".classify.constantize.find(permitted_params[:id])
      filename = nil
      content_type = nil

      if @asset.class.active_storage_activated? && @asset[:file].blank?
        if permitted_params[:transformation]&.values.present?
          @asset_version = @asset.try(:dynamic, permitted_params[:transformation])
          @asset_path = @asset_version&.blob&.attachments&.first&.record&.file&.service&.path_for(@asset_version.key)

          content_type = @asset_version.variation.content_type
          filename = @asset_version.blob.filename.to_s
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
      else
        if permitted_params[:transformation]&.values.present?
          @asset_version = @asset.try(permitted_params[:version], recreate: true)&.dynamic_version(name: permitted_params[:version], options: permitted_params[:transformation], process: true)
        else
          @asset_version = @asset.try(permitted_params[:version], recreate: true)
        end
        @asset_path = @asset_version&.path

        raise ActiveRecord::RecordNotFound if @asset_path.blank?

        content_type = @asset_version.content_type
        filename = @asset_version.file_name
      end

      headers['ETag'] = %("#{File.mtime(@asset_path)}-#{@asset_version.try(:size)}")
      headers['Last-Modified'] = File.mtime(@asset_path).httpdate
      headers.delete 'X-Frame-Options'

      send_file @asset_path, disposition: 'inline', filename: filename, type: content_type
    rescue StandardError => e
      not_found(e)
    end

    def processed
      id = permitted_params[:id]
      processed_asset_path = Rails.root.join('public/uploads' + request.path)

      # file_name = File.basename(processed_asset_path)
      # content_type = MiniMime.lookup_by_extension(File.extname(processed_asset_path).delete_prefix('.'))&.content_type

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
      params.permit(:klass, :id, :version, transformation: [:format, :width, :height])
    end
  end
end
