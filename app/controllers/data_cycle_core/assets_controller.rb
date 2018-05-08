module DataCycleCore
  class AssetsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    def index
      authorize! :index, DataCycleCore::Asset
      @assets = DataCycleCore::Asset.all
    end

    def create
      if asset_params[:file].present?
        object_type = DataCycleCore.asset_objects.find { |object| object == params[:type] }

        authorize! :create, object_type

        @asset = object_type.constantize.new(asset_params).set_content_type.set_file_size
        @asset.name = @asset.file.identifier if asset_params[:name].blank?
        @asset.creator_id = current_user.try(:id)

        @asset.save
      end

      respond_to(:js)
    end

    def update
      if asset_params[:file].present?
        object_type = DataCycleCore.asset_objects.find { |object| object == params[:type] }
        @asset = object_type.constantize.find(params[:id])

        authorize! :update, @asset

        @asset.update(asset_params)
      end

      respond_to do |format|
        format.js { render :create }
      end
    end

    def new_asset_object
      object_type = DataCycleCore.asset_objects.find { |object| object == additional_params[:definition]['type_name'] }

      @asset = object_type.constantize.new(asset_params).set_content_type.set_file_size
      @asset.creator_id = current_user.try(:id)

      if @asset.save
        @object = [@asset]
        respond_to(:js)
      end
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
