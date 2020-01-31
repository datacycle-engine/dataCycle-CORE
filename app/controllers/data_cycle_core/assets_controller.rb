# frozen_string_literal: true

module DataCycleCore
  class AssetsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    def index
      @html_target = permitted_params[:html_target]
      @selected = permitted_params[:selected]
      @append = permitted_params[:append] || false
      @page = permitted_params[:page] || 1
      @last_asset_type = permitted_params[:last_asset_type]
      @assets = DataCycleCore::Asset.accessible_by(current_ability).order(type: :asc, updated_at: :desc)
      @assets = @assets.where(type: permitted_params[:types]) if permitted_params[:types].present?
      @assets = @assets.where.not(id: permitted_params[:locked_assets].compact.uniq) if permitted_params[:locked_assets].present?
      @assets = @assets.page(@page).per(25)
      @asset_details = @assets.as_json(only: [:id, :name, :file_size, :content_type, :file], methods: :duplicate_candidates)
      @total = @assets.total_count
    end

    def create
      render(json: { error: I18n.t(:wrong_content_type, scope: [:controllers, :error], locale: DataCycleCore.ui_language) }) && return if asset_params[:file].blank? || asset_params[:type].blank?

      object_type = DataCycleCore.asset_objects.find { |a| a == asset_params[:type] }

      render(json: { error: I18n.t(:wrong_content_type, scope: [:controllers, :error], locale: DataCycleCore.ui_language) }) && return if object_type.blank?

      authorize! :create, object_type.constantize

      @asset = object_type.constantize.new(asset_params)
      @asset.name = asset_params[:file].original_filename if asset_params[:name].blank?
      @asset.creator_id = current_user.try(:id)

      if @asset.save
        render json: @asset.attributes.merge(duplicate: @asset.try(:duplicate_candidates).present?)
      else
        render(json: { error: @asset.errors.full_messages.join(', ') })
      end
    end

    def update
      return if asset_params[:file].blank?

      @asset = DataCycleCore::Asset.find(params[:id])

      authorize! :update, @asset

      if @asset.update(asset_params)
        render json: @asset
      else
        render(json: { error: @asset.errors.full_messages.join(', ') })
      end
    end

    def find
      authorize! :show, DataCycleCore::TextFile

      @duplicate = DataCycleCore::TextFile.accessible_by(current_ability, :update).find_by('type = ? AND name ILIKE ?', 'DataCycleCore::TextFile', find_params[:q])

      render json: @duplicate&.attributes
    end

    def destroy
      @asset = DataCycleCore::Asset.find(params[:id])

      authorize! :destroy, @asset

      @asset.destroy
    end

    def duplicate
      @asset = DataCycleCore::Asset.find(permitted_params[:id])
      @duplicate = @asset.duplicate
      @html_target = permitted_params[:html_target]
    end

    private

    def asset_params
      params.require(:asset).permit(:id, :name, :file, :type)
    end

    def permitted_params
      params.permit(:id, :append, :last_asset_type, :page, :type, :html_target, selected: [], locked_assets: [], types: [])
    end

    def find_params
      params.permit(:q)
    end
  end
end
