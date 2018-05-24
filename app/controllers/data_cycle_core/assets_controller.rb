# frozen_string_literal: true

module DataCycleCore
  class AssetsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)
    # authorize_resource :class => false # from cancancan (authorize)

    def index
      @assets = DataCycleCore::Asset.all
    end

    def new_asset_object
      object_type = DataCycleCore.asset_objects.find { |object| object == "DataCycleCore::#{additional_params[:definition]['asset_type'].to_s.try(:camelcase)}" }
      @asset = object_type.constantize.new(asset_params).set_content_type.set_file_size
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
      params.require(:asset).permit(:file)
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
