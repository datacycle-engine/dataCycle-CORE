module DataCycleCore
  class CreativeWorksController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def index

    end

    def show
      @creativeWork = DataCycleCore::CreativeWork.find_by(id: params[:id])
      if @creativeWork.nil?
        redirect_to root
      end
      render layout: "data_cycle_core/creative_works_show"
    end

    def new
      #only for testing
      @creativeWork = DataCycleCore::CreativeWork.new
      render layout: "data_cycle_core/creative_works_show"
    end

    def create
      @creativeWork = DataCycleCore::CreativeWork.new(creative_work_params)    # Not the final implementation!

      #todo: make this generic
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Thema", description: "CreativeWork").first
      validation = template.metadata['validation']

      @creativeWork.metadata = { 'validation' => validation }
      @creativeWork.save

      datahash = {'headline' => creative_work_params[:headline], 'creator' => current_user[:id]}
      @creativeWork.set_data_hash(datahash)

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

      render layout: "data_cycle_core/creative_works_show"
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
      update_params = {:headline => datahash[:headline]}
      @creativeWork.update_attributes(update_params)

      if @creativeWork.save
        flash[:success] = "CreativeWork updated"
        # redirect_to @creativeWork
        redirect_to edit_creative_work_path(@creativeWork)
      else
        render 'edit'
      end
    end

    def validate_single_data
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])

      datahash = creative_work_params[:datahash]
      valid = @creativeWork.validate(datahash)

      render :json => valid.to_json
    end

    #dev views for michi
    def demotopic

    end

    def demoarticle

    end

    private

      def creative_work_params
        params.require(:creative_work).permit(:headline, :datahash => [:headline,:description,:state => [],:topics => [],:markets => [],:tags => [], :validityPeriod => [:validFrom, :validUntil] ])
        # params.require(:creative_work).permit!
      end

  end
end
