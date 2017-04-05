module DataCycleCore
  class CreativeWorksController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def index
      @creativeWorks = CreativeWork.order(updated_at: :desc).page(params[:page])
    end

    def show
      @creativeWork = CreativeWork.find_by(id: params[:id])
      if @creativeWork.nil?
        render action: "index"
      end
    end

  end
end
