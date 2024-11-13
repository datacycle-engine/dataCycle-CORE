# frozen_string_literal: true

module DataCycleCore
  class MissingAssetController < ApplicationController
    include DataCycleCore::ErrorHandler
    include DataCycleCore::AssetLoaderConcern

    protect_from_forgery with: :exception

    def show
      load_asset_from_params

      if permitted_params[:transformation]&.values.present? && @asset.respond_to?(:dynamic)
        load_asset_path_with_transformation
      elsif permitted_params[:version] == 'original' || permitted_params[:version].blank?
        load_original_path
      else
        load_asset_version_path
      end

      raise ActiveRecord::RecordNotFound if @asset_path.blank?

      headers['ETag'] = @asset_version&.checksum
      headers['Last-Modified'] = @asset_version.created_at.httpdate
      headers.delete 'X-Frame-Options'

      send_file @asset_path, disposition: 'inline', filename: @filename, type: @content_type
    rescue StandardError => e
      not_found(e)
    end

    def processed
      id = permitted_params[:id]
      processed_asset_path = Rails.root.join("public/uploads#{request.path}")

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
