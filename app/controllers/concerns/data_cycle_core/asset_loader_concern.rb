# frozen_string_literal: true

module DataCycleCore
  module AssetLoaderConcern
    extend ActiveSupport::Concern

    private

    def load_asset_from_params
      if asset_params[:id].respond_to?(:uuid?) && asset_params[:id].uuid?
        @asset = DataCycleCore::Thing.find_by(id: asset_params[:id]).try(:asset) ||
                 DataCycleCore::Asset.find_by(id: asset_params[:id]) ||
                 ActiveStorage::Blob.find_by(id: asset_params[:id])&.attachments&.first&.record
      elsif asset_params[:id].present?
        slug = asset_params[:id].split('.').first
        @asset = DataCycleCore::Thing::Translation.find_by(slug: slug)&.translated_model.try(:asset)
      end

      raise ActiveRecord::RecordNotFound if @asset.nil?
    end

    def load_asset_path_with_transformation
      @asset_version = @asset.try(:dynamic, asset_params[:transformation])
      @asset_path = @asset_version&.blob&.attachments&.first&.record&.file&.service&.path_for(@asset_version.key)
      @content_type = @asset_version.variation.content_type
      @filename = "#{@asset.filename_without_extension}.#{MiniMime.lookup_by_content_type(@content_type)&.extension}"
    end

    def load_original_path
      @asset = @asset.file if @asset.is_a?(DataCycleCore::Asset)
      @asset_version = @asset
      @asset_path = @asset_version&.service&.path_for(@asset_version.key)
      @content_type = @asset_version.content_type
      @filename = @asset.record.filename.to_s
    end

    def load_asset_version_path
      @asset_version = @asset.try(asset_params[:version], { recreate: true })
      @asset_path = @asset_version&.blob&.attachments&.first&.record&.file&.service&.path_for(@asset_version.key)
      @content_type = @asset_version.variation.content_type
      @filename = @asset.filename.to_s
    end

    def asset_params
      params.permit(:id, :version, transformation: [:format, :width, :height])
    end
  end
end
