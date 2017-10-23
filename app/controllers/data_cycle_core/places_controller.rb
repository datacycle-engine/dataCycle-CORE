module DataCycleCore
  class PlacesController < ContentsController
    before_action :authenticate_user!   # from devise (authenticate)
    # load_and_authorize_resource       # from cancancan (authorize)

    def index
      @places = DataCycleCore::Place.all().where(:template => false).order(updated_at: :desc).page(params[:page])
      @place = DataCycleCore::Place.new
    end

    def show
      session[:trail] = params[:trail] unless params[:trail].nil?
      @place = DataCycleCore::Place.find_by(id: params[:id])

      if @place.nil?
        redirect_back(fallback_location: root_path)
      end

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end
      I18n.with_locale(@place.first_available_locale) do
        @dataSchema = @place.get_data_hash
        # do something if no german version exists
        if @dataSchema.nil?
          @dataSchema = I18n.with_locale(@place.translated_locales.first){@place.get_data_hash}
        end

        respond_to do |format|
          format.json { redirect_to api_v1_content_path(type: 'places', id: params[:id]) }
          format.html {
            render layout: "data_cycle_core/creative_works_edit"
          }
        end
      end
    end

    def create
      I18n.with_locale(params[:locale] || I18n.locale) do
        object_params = place_params('places', params[:template], 'Place')
        @place = DataCycleCore::DataHashService.create_internal_object('places', params[:template], 'Place', object_params, current_user)

        if @place.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        respond_to do |format|
          #validate ?
          if !@place.nil? && @place.save
            flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Place'
            format.html { redirect_to @place }
            format.json { render :json => @place }
          else
            redirect_back(fallback_location: root_path)
            return
          end
        end
      end
    end

    def edit

      @place = DataCycleCore::Place.find(params[:id])
      I18n.with_locale(@place.first_available_locale) do
        @dataSchema = @place.get_data_hash
        render layout: "data_cycle_core/creative_works_edit"
      end
    end

    def update
      @place = DataCycleCore::Place.find(params[:id])

      object_params = place_params('places', @place.metadata['validation']['name'], @place.metadata['validation']['description'])
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],@place.metadata['validation'], false)

      # todo: implement preprocessor
      datahash = set_location(datahash)

      valid = @place.set_data_hash(datahash, current_user)

      if valid.key?(:error) && !valid[:error].empty?
        flash[:error] = valid[:error]
        redirect_to edit_place_path(@place)
        return
      end

      if @place.save
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Place'

        if Rails.env.development?
          redirect_back(fallback_location: root_path)
        else
          redirect_to place_path(@place, trail: session[:trail])
        end

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

      def create_params
      end

      def place_params(storage_location, template_name, template_description)
        datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name, template_description)
        params.require(:place).permit(:datahash => datahash)

      end

      #todo: implement as preprocessor
      def set_location(datahash)
        if !datahash['longitude'].nil? && !datahash['longitude'].blank? && !datahash['latitude'].nil? && !datahash['latitude'].blank?
          datahash['location'] = RGeo::Geographic.spherical_factory(srid: 4326).point(datahash['longitude'].to_f, datahash['latitude'].to_f)
        end
        return datahash
      end

  end
end
