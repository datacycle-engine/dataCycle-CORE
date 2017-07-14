module DataCycleCore
  class PlacesController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Ort", "", "/places"

    def index
      @places = DataCycleCore::Place.all().where(:template => false).order(updated_at: :desc)
      @place = DataCycleCore::Place.new
    end

    def show
      @Place = DataCycleCore::Place.find_by(id: params[:id])
      set_breadcrumb_for @Place

      if @Place.nil?
        redirect_to root
      end

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      @dataSchema = @Place.get_data_hash

      #only for testing
      @creativeWork = @Place

      render layout: "data_cycle_core/creative_works_edit"

    end

    def new
      @Place = DataCycleCore::Place.new
    end

    def create

      @Place = create_internal(params[:template])

      set_breadcrumb_for @Place

      if @Place.nil?
        redirect_to :back
        return
      end

      respond_to do |format|
        #validate ?
        if !@Place.nil? && @Place.save
          flash[:success] = "Successfully added new Place!"
          format.html { redirect_to @Place }
          format.json { render :json => @Place }
        else
          redirect_to :back
          return
        end
      end

    end

    def edit

      @creativeWork = DataCycleCore::Place.find(params[:id])
      set_breadcrumb_for @creativeWork
      add_breadcrumb '<i aria-hidden="true" class="fa fa-pencil"></i> Bearbeiten'.html_safe, "", creative_work_path(@creativeWork)
      @dataSchema = @creativeWork.get_data_hash

      render layout: "data_cycle_core/creative_works_edit"
    end

    def update
      @creativeWork = DataCycleCore::Place.find(params[:id])
      set_breadcrumb_for @creativeWork
      add_breadcrumb "", "Edit", creative_work_path(@creativeWork)

      datahash = Place_params[:datahash]

      # add creator id
      datahash[:creator] = current_user[:id]
      valid = @creativeWork.validate(datahash)

      if valid.key?(:error) && !valid[:error].empty?
        flash[:error] = valid[:error]
        redirect_to edit_Place_path(@creativeWork)
        return
      end

      @creativeWork.set_data_hash(datahash)

      # needed because headline != title
      update_params = {:headline => datahash[:headline]}
      @creativeWork.update_attributes(update_params)

      if @creativeWork.save
        flash[:success] = "Place updated"
        # redirect_to @creativeWork
        redirect_to edit_Place_path(@creativeWork)
      else
        render 'edit'
      end
    end

    def validate_single_data
      @Place = DataCycleCore::Place.find(params[:id])

      datahash = Place_params[:datahash]
      valid = @Place.validate(datahash)

      render :json => valid.to_json
    end

    private

      def place_params
        params.require(:Place).permit(:givenName, :familyName, :datahash => [:givenName, :familyName, :honorificPrefix, :telephone, :faxNumber, :email, :jobTitle])
        # params.require(:creative_work).permit!
      end

      def create_internal(template)

        place = DataCycleCore::Place.new(Place_params)

        template = DataCycleCore::Place.where(template: true, headline: template, description: "contentLocation").first
        validation = template.metadata['validation']

        place.metadata = { 'validation' => validation }
        place.save

        datahash = {'givenName' => place_params[:givenName], 'familyName' => place_params[:familyName], 'jobTitle' => place_params[:datahash][:jobTitle], 'creator' => current_user[:id]}

        place.set_data_hash(datahash)

        #validate ?
        if place.save
          return place
        else
          return nil
        end

      end

      def set_breadcrumb_for place
        #set_breadcrumb_for creativeWork.parent if creativeWork.parent
        add_breadcrumb place.metadata['validation']['name'], "#{place.name}", place_path(place.id)
      end

  end
end
