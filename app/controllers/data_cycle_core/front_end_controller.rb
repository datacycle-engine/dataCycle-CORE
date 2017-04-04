module DataCycleCore
  class FrontEndController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def index
      @creativeWorks = CreativeWork.order(created_at: :desc).page(params[:page])
    end

  end
end
