# frozen_string_literal: true

module DataCycleCore
  class AssetsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    def index
      authorize! :index, DataCycleCore::Asset
      @assets = DataCycleCore::Asset.all
    end

    def create
      if asset_params[:file].present?
        object_type = DataCycleCore.asset_objects.find { |object| object == permitted_params[:type] }

        authorize! :create, object_type.constantize

        @asset = object_type.constantize.new(asset_params)
        @asset.name = @asset.file.identifier if asset_params[:name].blank?
        @asset.creator_id = current_user.try(:id)

        @asset.save
      end

      respond_to(:js)
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
      return unless @asset.save
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
      params.permit(:id, :type)
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
