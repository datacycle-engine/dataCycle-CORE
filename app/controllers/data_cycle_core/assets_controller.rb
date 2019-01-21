# frozen_string_literal: true

module DataCycleCore
  class AssetsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    def index
      authorize! :index, DataCycleCore::Asset
      @html_target = permitted_params[:html_target]
      @selected = permitted_params[:selected]
      @assets = DataCycleCore::Asset.accessible_by(current_ability).order(updated_at: :desc)
      @assets = @assets.where(type: permitted_params[:types]) if permitted_params[:types].present?
      @assets = @assets.where.not(id: permitted_params[:locked_assets].compact) if permitted_params[:locked_assets].present?
    end

    def create
      return if asset_params[:file].blank? || asset_params[:type].blank?

      object_type = DataCycleCore.asset_objects.find { |a| a == asset_params[:type] }

      render(json: { error: I18n.t(:wrong_content_type, scope: [:controllers, :error], locale: DataCycleCore.ui_language) }) && return if object_type.blank?

      authorize! :create, object_type.constantize

      @asset = object_type.constantize.new(asset_params)
      @asset.name = asset_params[:file].original_filename if asset_params[:name].blank?
      @asset.creator_id = current_user.try(:id)
      if @asset.save
        render json: @asset
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
      authorize! :show, DataCycleCore::DataCycleFile

      @duplicate = DataCycleCore::DataCycleFile.accessible_by(current_ability, :update).find_by('type = ? AND name ILIKE ?', 'DataCycleCore::DataCycleFile', find_params[:q])

      render json: @duplicate&.attributes
    end

    private

    def asset_params
      params.require(:asset).permit(:id, :name, :file, :type)
    end

    def permitted_params
      params.permit(:id, :type, :html_target, :selected, locked_assets: [], types: [])
    end

    def find_params
      params.permit(:q)
    end
  end
end
