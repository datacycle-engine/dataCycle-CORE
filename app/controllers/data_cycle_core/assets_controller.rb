module DataCycleCore
  class AssetsController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    # authorize_resource :class => false         # from cancancan (authorize)

    def index
      @assets = DataCycleCore::Asset.all
    end

    def show

    end

    def new
      @asset = DataCycleCore::Asset.new
    end

    def create

      @asset = DataCycleCore::Image.new(asset_params).set_content_type.set_file_size
      @asset.creator_id = current_user.try(:id)


      @asset.save
      raise @asset.inspect

      if @asset.save
        flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Asset', locale: DataCycleCore.ui_language
        redirect_to assets_path
      else
        flash[:error] = @asset.try(:errors).try(:first).try(:[], 1)
        redirect_to assets_path
      end

    end

    def destroy

    end


    private

    def asset_params
      params.require(:asset).permit(:file)
    end
  end
end
