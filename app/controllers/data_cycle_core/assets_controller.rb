# frozen_string_literal: true

module DataCycleCore
  class AssetsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    def index
      authorize! :index, DataCycleCore::Asset
      @html_target = permitted_params[:html_target]
      @selected = permitted_params[:selected]
      @assets = DataCycleCore::Asset.accessible_by(current_ability).order(:type)
      @assets = @assets.where(type: permitted_params[:types]) if permitted_params[:types].present?
      @assets = @assets.where.not(id: permitted_params[:locked_assets]) if permitted_params[:locked_assets].present?
    end

    def create
      return if asset_params[:file].blank?

      object_type = DataCycleCore.asset_objects.find do |object|
        object.underscore.include?(asset_params[:file].content_type&.gsub('application/pdf', 'pdf')&.gsub('application', 'text_file')&.split('/')&.first&.underscore)
      end

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
      if asset_params[:file].present?
        object_type = DataCycleCore.asset_objects.find { |object| object == permitted_params[:type] }
        @asset = object_type.constantize.find(permitted_params[:id])

        authorize! :update, @asset

        @asset.update(asset_params)
      end

      respond_to do |format|
        format.js { render :create }
      end
    end

    def new_asset_object
      object_type = DataCycleCore.asset_objects.find { |object| object == "DataCycleCore::#{additional_params[:definition]['asset_type'].to_s.try(:camelcase)}" }
      @asset = object_type.constantize.new(asset_params)
      @asset.creator_id = current_user.try(:id)
      @asset.save
      @object = [@asset]
      respond_to(:js)
    end

    def remove_asset_object
      additional_params

      @object = []
      respond_to(:js)
    end

    private

    def asset_params
      params.require(:asset).permit(:name, :file)
    end

    def permitted_params
      params.permit(:id, :type, :html_target, :selected, locked_assets: [], types: [])
    end

    def additional_params
      @additional_params = {
        asset_object_id: params['asset']['asset_object_id'],
        key: params['asset']['key'],
        definition: JSON.parse(params['asset']['definition']),
        options: JSON.parse(params['asset']['options'])
      }
    end
  end
end
