module DataCycleCore
  class CreativeWorksController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def index
      @creativeWork = CreativeWork.new
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

      #Testing
      template = DataCycleCore::CreativeWork.where(template: true).first
      validation = template.metadata['validation']
      @creativeWork.metadata = { 'validation' => validation }

      if @creativeWork.save
        flash[:success] = "Successfully added new creativeWork!"
        redirect_to @creativeWork
      else
        render 'new'
      end
    end

    def edit
      @creativeWork = CreativeWork.find(params[:id])
    end

    def update
      @creativeWork = CreativeWork.find(params[:id])
      if @creativeWork.update_attributes(creative_work_params)
        flash[:success] = "CreativeWork updated"
        redirect_to @creativeWork
      else
        render 'edit'
      end
    end

    private

      def creative_work_params
        params.require(:creative_work).permit(:headline, :description)
      end

  end
end
