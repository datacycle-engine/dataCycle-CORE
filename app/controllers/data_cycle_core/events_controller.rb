module DataCycleCore
  class EventsController < ContentsController
    before_action :authenticate_user! # from devise (authenticate)
    # load_and_authorize_resource       # from cancancan (authorize)

    def index
      @paginateObject = DataCycleCore::Event.all.where(template: false).order(updated_at: :desc).page(params[:page])
      @event = DataCycleCore::Event.new
    end

    def show
      @content = DataCycleCore::Event.find_by(id: params[:id])

      redirect_back(fallback_location: root_path) if @content.nil?

      if params[:mode].nil?
        @mode = 'flex'
      else
        @mode = params[:mode].to_s
      end
      I18n.with_locale(@content.first_available_locale) do
        @dataSchema = @content.get_data_hash
        # do something if no german version exists
        @dataSchema = I18n.with_locale(@content.translated_locales.first) { @content.get_data_hash } if @dataSchema.nil?

        respond_to do |format|
          format.json { redirect_to api_v1_content_path(type: 'events', id: params[:id]) }
          format.html
        end
      end
    end

    def create
      I18n.with_locale(params[:locale] || I18n.locale) do
        object_params = event_params('events', params[:template], 'Event')
        @event = DataCycleCore::DataHashService.create_internal_object('events', params[:template], 'Event', object_params, current_user)

        if @event.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        respond_to do |format|
          # validate ?
          if !@event.nil? && @event.save
            flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Event', locale: DataCycleCore.ui_language
            format.html { redirect_to @event }
            format.json { render json: @event }
          else
            redirect_back(fallback_location: root_path)
            return
          end
        end
      end
    end

    def edit
      @content = DataCycleCore::Event.find(params[:id])
      if params[:locale] && !@content.translated_locales.include?(params[:locale])
        I18n.with_locale(params[:locale]) do
          @content.save
        end
      end

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        @dataSchema = @content.get_data_hash
        render 'edit'
      end
    end

    def update
      @event = DataCycleCore::Event.find(params[:id])
      I18n.with_locale(@event.first_available_locale(params[:locale])) do
        object_params = event_params('events', @event.metadata['validation']['name'], @event.metadata['validation']['description'])
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @event.metadata['validation'], false)

        valid = @event.set_data_hash(data_hash: datahash, current_user: current_user)

        if valid.key?(:error) && !valid[:error].empty?
          flash[:error] = valid[:error]
          redirect_to edit_event_path(@event)
          return
        end

        if @event.save
          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Event', locale: DataCycleCore.ui_language

          if Rails.env.development?
            redirect_back(fallback_location: root_path)
          else
            redirect_to event_path(@event, watch_list_id: @watch_list)
          end

        else
          render 'edit'
        end
      end
    end

    def destroy
      @event = DataCycleCore::Event.find(params[:id])
      @event.destroy_content
      @event.destroy

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Event', locale: DataCycleCore.ui_language

      redirect_to events_path
    end

    def validate_single_data
      @event = DataCycleCore::Event.find(params[:id])
      object_params = event_params('events', @event.metadata['validation']['name'], @event.metadata['validation']['description'])

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @event.metadata['validation'])
      valid = @event.validate(datahash)

      render json: valid.to_json
    end

    private

    def create_params
    end

    def event_params(storage_location, template_name, template_description)
      datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name, template_description)
      params.require(:event).permit(datahash: datahash)
    end
  end
end
