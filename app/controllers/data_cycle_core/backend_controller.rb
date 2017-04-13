module DataCycleCore
  class BackendController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def index
      @creativeWorks = CreativeWork.order(created_at: :desc).page(params[:page])

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end
      
    end

    def vue

    end

  end
end
