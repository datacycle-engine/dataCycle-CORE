# frozen_string_literal: true

module DataCycleCore
  class MissingAssetController < ApplicationController
    include DataCycleCore::ErrorHandler
    protect_from_forgery with: :exception

    def show
      @asset = "data_cycle_core/#{permitted_params[:klass]}".classify.constantize.find(permitted_params[:id])

      if permitted_params[:transformation]&.values.present?
        @asset_version = @asset.try(permitted_params[:version], recreate: true)&.dynamic_version(name: permitted_params[:version], options: permitted_params[:transformation], process: true)
      else
        @asset_version = @asset.try(permitted_params[:version], recreate: true)
      end

      @asset_path = @asset_version&.path

      raise ActiveRecord::RecordNotFound if @asset_path.blank?

      headers['ETag'] = %("#{File.mtime(@asset_path)}-#{@asset_version.try(:size)}")
      headers['Last-Modified'] = File.mtime(@asset_path).httpdate
      headers.delete 'X-Frame-Options'

      send_file @asset_path, disposition: 'inline', filename: @asset_version.file_name, type: @asset_version.content_type
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
