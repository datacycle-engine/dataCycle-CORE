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
        redirect_to root
      end
    end

    def new
      @creativeWork = CreativeWork.new
      render layout: "data_cycle_core/creative_works_new"
    end

    def create
      @creativeWork = CreativeWork.new(creative_work_params)    # Not the final implementation!
      if @creativeWork.save
        flash[:success] = "Successfully added new creativeWork!"
        redirect_to @creativeWork
      else
        render 'new'
      end
    end

    private

      def creative_work_params
        params.require(:create_work).permit(:headline)
      end

  end
end
