# frozen_string_literal: true

module DataCycleCore
  class MissingAssetController < ApplicationController
    include DataCycleCore::ErrorHandler
    include DataCycleCore::AssetLoaderConcern

    protect_from_forgery with: :exception, except: :imgproxy_url

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

      headers['ETag'] = @asset_version&.blob&.checksum
      headers['Last-Modified'] = @asset_version&.blob&.created_at&.httpdate
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

      send_file processed_asset_path, disposition: 'inline'
    rescue StandardError => e
      not_found(e)
    end

    def imgproxy_url
      render(json: { error: I18n.t('controllers.error.feature_not_enabled', locale: helpers.active_ui_locale) }, status: :unauthorized) && return unless DataCycleCore::Feature::ImageProxy.enabled?

      image_processing = permitted_params[:transformation]&.slice(:resize_type, :width, :height, :enlarge, :gravity, :extension)&.to_h
      render(json: { error: 'Missing required parameters' }, status: :bad_request) && return if image_processing.blank?
      image_processing[:width] ||= image_processing[:height]
      image_processing[:height] ||= image_processing[:width]

      render(json: { error: 'Missing required parameters' }, status: :bad_request) && return unless image_processing.slice(:width, :height).values.all?(&:present?)

      image_processing[:enlarge] ||= 0
      image_processing[:resize_type] ||= 'fit'
      image_processing[:gravity] ||= 'sm'
      render(json: { error: 'Width, height and enlarge must be numbers' }, status: :bad_request) && return unless image_processing.slice(:width, :height, :enlarge).values.all?(Numeric)

      content = DataCycleCore::Thing.find(permitted_params[:id])

      format = image_processing[:extension]
      image_processing[:format] = format if format.present?

      url = DataCycleCore::Feature::ImageProxy.process_image(
        content:,
        variant: 'dynamic',
        image_processing:
      )
      render(json: { url: }, status: :ok) && return
    rescue StandardError => e
      render(json: { error: e.message }, status: :unprocessable_entity) && return
    end

    private

    def permitted_params
      params.permit(:klass, :klass_namespace, :id, :version, :file, transformation: [:format, :width, :height, :resize_type, :gravity, :enlarge, :extension])
    end
  end
end
