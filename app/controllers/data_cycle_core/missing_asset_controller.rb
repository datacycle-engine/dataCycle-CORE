# frozen_string_literal: true

module DataCycleCore
  class MissingAssetController < ActionController::Base
    include DataCycleCore::ErrorHandler
    protect_from_forgery with: :exception

    def show
      @asset = "data_cycle_core/#{permitted_params[:klass]}".classify.constantize.find(permitted_params[:id])

      transformations = permitted_params[:transformation]
      transformations.delete('format') if transformations&.key?('format') &&
                                          @asset.file.extension_white_list.exclude?(transformations['format']) &&
                                          DataCycleCore::Feature::Serialize.asset_versions(@asset.things.first).exclude?(transformations['format'])

      if transformations&.values.present?
        @asset_version = @asset.try(permitted_params[:version], recreate: true)&.dynamic_version(name: permitted_params[:version], options: transformations, process: true)
      else
        @asset_version = @asset.try(permitted_params[:version], recreate: true)
      end

      @asset_path = @asset_version&.path

      raise ActiveRecord::RecordNotFound if @asset_path.blank?

      headers['ETag'] = %("#{File.mtime(@asset_path)}-#{@asset_version.try(:size)}")
      headers['Last-Modified'] = File.mtime(@asset_path).httpdate
      send_file @asset_path, disposition: 'inline', filename: @asset_version.file_name, type: @asset_version.content_type
    rescue StandardError => e
      not_found(e)
    end

    private

    def permitted_params
      params.permit(:klass, :id, :version, transformation: [:format, :width, :height])
    end
  end
end
