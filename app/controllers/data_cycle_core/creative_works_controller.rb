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
      datahash = creative_work_params[:datahash]

      # add creator id
      datahash[:creator] = current_user[:id]
      valid = @creativeWork.validate(datahash)

      if valid.key?(:error) && !valid[:error].empty?
        flash[:error] = valid[:error]
        redirect_to edit_creative_work_path(@creativeWork)
        return
      end

      @creativeWork.set_data_hash(datahash)

      # needed because headline != title
      update_params = {:headline => datahash[:title]}
      @creativeWork.update_attributes(update_params)

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
        params.require(:creative_work).permit(:datahash => [:title,:description,:validityPeriod => [:validFrom, :validUntil] ])
        # params.require(:creative_work).permit!
      end

  end
end
