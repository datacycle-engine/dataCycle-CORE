# frozen_string_literal: true

module DataCycleCore
  class MissingAssetController < ActionController::Base
    protect_from_forgery with: :exception

    def show
      @asset = "data_cycle_core/#{permitted_params[:klass]}".classify.constantize.find(permitted_params[:id])
      if permitted_params[:version] == 'original'
        @asset_version = @asset.try(:file)
      else
        @asset_version = @asset.try(permitted_params[:version], recreate: true)
      end

      @asset_path = @asset_version&.path

      raise ActiveRecord::RecordNotFound if @asset_path.blank?

      headers['ETag'] = %("#{File.mtime(@asset_path)}-#{File.size(@asset_path)}")
      headers['Last-Modified'] = File.mtime(@asset_path).httpdate
      send_file @asset_path, disposition: 'inline', filename: @asset_version.file_name, type: @asset_version.content_type
    end

    private

    def permitted_params
      params.permit(:klass, :id, :version)
    end
  end
end
