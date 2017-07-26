module DataCycleCore
  class PlacesController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Ort", "", "/places"

    def index
      @places = DataCycleCore::Place.all().where(:template => false).order(updated_at: :desc).page(params[:page])
      @place = DataCycleCore::Place.new
    end

    def show
      @place = DataCycleCore::Place.find_by(id: params[:id])
      set_breadcrumb_for @place

      if @place.nil?
        redirect_to root
      end

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      @dataSchema = @place.get_data_hash
      # do something if no german version exists
      if @dataSchema.nil?
        @dataSchema = I18n.with_locale(@place.translated_locales.first){@place.get_data_hash}
      end

      #only for testing
      @creativeWork = @place

      render layout: "data_cycle_core/creative_works_edit"

    end

    def new
      @place = DataCycleCore::Place.new
    end

    def create

      @place = create_internal(params[:template])

      set_breadcrumb_for @place

      if @place.nil?
        redirect_to :back
        return
      end

      respond_to do |format|
        #validate ?
        if !@place.nil? && @place.save
          flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Place'
          format.html { redirect_to @place }
          format.json { render :json => @place }
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

      object_params = place_params('places', @creativeWork.metadata['validation']['name'], 'Place')
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],@creativeWork.metadata['validation'], false)

      # todo: implement preprocessor
      datahash = set_location(datahash)

      valid = @creativeWork.validate(datahash)

      if valid.key?(:error) && !valid[:error].empty?
        flash[:error] = valid[:error]
        redirect_to edit_place_path(@creativeWork)
        return
      end

      @creativeWork.set_data_hash(datahash)

      # needed because headline != title
      update_params = {:headline => datahash[:headline]}
      @creativeWork.update_attributes(update_params)

      if @creativeWork.save
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Place'
        # redirect_to @creativeWork
        redirect_to edit_place_path(@creativeWork)
      else
        render 'edit'
      end
    end

    def validate_single_data
      @place = DataCycleCore::Place.find(params[:id])
      object_params = place_params('places', @place.metadata['validation']['name'], 'Place')

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],@place.metadata['validation'])
      valid = @place.validate(datahash)

      render :json => valid.to_json
    end

    private

      def place_params(storage_location, template_name, template_description)

        datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name, template_description)
        params.require(:place).permit(:name, :datahash => datahash)

      end

      #todo: implement as preprocessor
      def set_location(datahash)
        if !datahash['longitude'].nil? && !datahash['longitude'].blank? && !datahash['latitude'].nil? && !datahash['latitude'].blank?
          datahash['location'] = RGeo::Geographic.spherical_factory(srid: 4326).point(datahash['longitude'].to_f, datahash['latitude'].to_f)
        end
        return datahash
      end

      def create_internal(template)

        object_params = place_params('places', template, 'Place')
        place = DataCycleCore::Place.new(place_params)

        template = DataCycleCore::Place.where(template: true, headline: template, description: "Place").first
        validation = template.metadata['validation']

        place.metadata = { 'validation' => validation }
        place.save

        if !object_params[:datahash].nil?
          datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],place.metadata['validation'])
          datahash[:creator] = current_user[:id]
        end

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
        add_breadcrumb 'Ort', place.name, place_path(place.id)
      end

  end
end
