module DataCycleCore
  class PlacesController < ContentsController
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource except: [:validate_single_data, :compare] # from cancancan (authorize)

    def show
      @content = DataCycleCore::Place.find_by(id: params[:id])

      redirect_back(fallback_location: root_path) && return if @content.nil?

      I18n.with_locale(@content.first_available_locale) do
        @dataSchema = @content.get_data_hash
        # do something if no german version exists
        @dataSchema = I18n.with_locale(@content.translated_locales.first) { @content.get_data_hash } if @dataSchema.nil?

        respond_to do |format|
          format.json { redirect_to api_v1_content_path(type: 'places', id: params[:id]) }
          format.html { render 'show' }
        end
      end
    end

    def create
      I18n.with_locale(params[:locale] || I18n.locale) do
        object_params = place_params('places', params[:template])
        @place = DataCycleCore::DataHashService.create_internal_object('places', params[:template], object_params, current_user)

        if @place.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        respond_to do |format|
          # validate ?
          if !@place.nil? && @place.save
            format.html do
              flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @place.template_name, locale: DataCycleCore.ui_language
              redirect_to @place
            end
            format.js
          else
            redirect_back(fallback_location: root_path)
            return
          end
        end
      end
    end

    def edit
      @content = DataCycleCore::Place.find(params[:id])

      if params[:locale] && !@content.translated_locales.include?(params[:locale]) && I18n.available_locales.include?(params[:locale]&.to_sym) && (DataCycleCore.translatable_types & [@content.class.name, @content.template_name]).present?
        I18n.with_locale(params[:locale]) do
          @content.save
        end
      end

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        unless can?(:edit, @content)
          redirect_to place_path(@content), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)
          return
        end
        @dataSchema = @content.get_data_hash
        render 'edit'
      end
    end

    def update
      @place = DataCycleCore::Place.find(params[:id])
      I18n.with_locale(@place.first_available_locale(params[:locale])) do
        object_params = place_params('places', @place.template_name)
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @place.schema)

        # TODO: implement preprocessor
        datahash = set_location(datahash)

        data_hash_has_changes = DataCycleCore::DataHashService.data_hash_is_dirty?(
          datahash.merge({ 'id' => @place.id}),
          @place.get_data_hash
        )

        unless data_hash_has_changes
          flash[:info] = I18n.t :not_modified, scope: [:controllers, :info], data: @place.template_name, locale: DataCycleCore.ui_language
          if (Rails.env.development? || params[:splitview]) && !params[:finalize]
            redirect_back(fallback_location: root_path)
          else
            redirect_to places_path(@place, watch_list_id: @watch_list)
          end
          return
        end

        valid = @place.set_data_hash(data_hash: datahash, current_user: current_user)

        if valid.key?(:error) && !valid[:error].empty?
          flash[:error] = valid[:error]
          redirect_to edit_place_path(@place)
          return
        end

        if @place.save
          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @place.template_name, locale: DataCycleCore.ui_language

          if Rails.env.development?
            redirect_back(fallback_location: root_path)
          else
            redirect_to place_path(@place, watch_list_id: @watch_list)
          end

        else
          render 'edit'
        end
      end
    end

    def destroy
      @place = DataCycleCore::Place.find(params[:id])
      @place.destroy_content
      @place.destroy

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Ort', locale: DataCycleCore.ui_language

      redirect_to places_path
    end

    def validate_single_data
      @place = DataCycleCore::Place.find(params[:id])
      object_params = place_params('places', @place.template_name)

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @place.schema)
      valid = @place.validate(datahash)

      render json: valid.to_json
    end

    private

    def create_params
    end

    def place_params(storage_location, template_name)
      datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name)
      params.require(:place).permit(datahash: datahash)
    end

    # TODO: implement as preprocessor
    def set_location(datahash)
      datahash['location'] = RGeo::Geographic.spherical_factory(srid: 4326).point(datahash['longitude'].to_f, datahash['latitude'].to_f) if !datahash['longitude'].nil? && !datahash['longitude'].blank? && !datahash['latitude'].nil? && !datahash['latitude'].blank?
      datahash
    end
  end
end
