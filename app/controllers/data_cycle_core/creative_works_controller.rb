module DataCycleCore
  class CreativeWorksController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def index
      @creativeWork = DataCycleCore::CreativeWork.new
      @creativeWorks = DataCycleCore::CreativeWork.order(updated_at: :desc).page(params[:page])
    end

    def show
      @creativeWork = DataCycleCore::CreativeWork.find_by(id: params[:id])
      if @creativeWork.nil?
        redirect_to root
      end
    end

    def new
      @creativeWork = DataCycleCore::CreativeWork.new
      render layout: "data_cycle_core/creative_works_new"
    end

    def create
      @creativeWork = DataCycleCore::CreativeWork.new(creative_work_params)    # Not the final implementation!

      #Testing
      template = DataCycleCore::CreativeWork.where(template: true).first
      validation = template.metadata['validation']
      @creativeWork.metadata = { 'validation' => validation }
      @creativeWork.set_data_type({"Titel" => creative_work_params[:headline]})
      #validate ?
      if @creativeWork.save
        flash[:success] = "Successfully added new creativeWork!"
        redirect_to @creativeWork
      else
        render 'new'
      end
    end

    def edit
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      @data = @creativeWork.get_data_type
      @dataSchema = @creativeWork.get_data_hash

      #testing classifications


    end

    def update
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      @creativeWork.update_attributes(creative_work_params)
      # @creativeWork.set_data_type({"Titel" => creative_work_params[:headline], "Beschreibung" => creative_work_params[:description]})

      @creativeWork.set_data_hash(creative_work_params[:datahash])
      test = creative_work_params

      if @creativeWork.save
        flash[:success] = "CreativeWork updated"
        redirect_to @creativeWork
      else
        render 'edit'
      end
    end

    #dev views for michi
    def demotopic

    end

    def demoarticle

    end

    private

      def creative_work_params
        params.require(:creative_work).permit(:headline, :datahash => [:title,:description])
        # params.require(:creative_work).permit!
      end

  end
end
