module DataCycleCore
  class BackendController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def index

      if params[:search]
        @allDataCycleObjects = CreativeWork.search(params[:search]).order(created_at: :desc)
      else
        @allDataCycleObjects = CreativeWork.order(created_at: :desc)
      end

      @dataCycleObjects = @allDataCycleObjects.page(params[:page])

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
