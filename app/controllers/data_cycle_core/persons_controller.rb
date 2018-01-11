module DataCycleCore
  class PersonsController < ContentsController
    before_action :authenticate_user!   # from devise (authenticate)
    load_and_authorize_resource         # from cancancan (authorize)

    def index
      @paginateObject = DataCycleCore::Person.all().where(:template => false).order(updated_at: :desc).page(params[:page])
      @person = DataCycleCore::Person.new
    end

    def show
      @content = DataCycleCore::Person.find_by(id: params[:id])

      if @content.nil?
        redirect_back(fallback_location: root_path)
      end

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end
      I18n.with_locale(@content.first_available_locale) do
        @dataSchema = @content.get_data_hash

        respond_to do |format|
          format.json { redirect_to api_v1_content_path(type: 'persons', id: params[:id]) }
          format.html
        end
      end
    end

    def create
      I18n.with_locale(params[:locale] || I18n.locale) do
        object_params = person_params('persons', params[:template], 'Person')
        @person = DataCycleCore::DataHashService.create_internal_object('persons', params[:template], 'Person', object_params, current_user)

        if @person.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        respond_to do |format|
          #validate ?
          if !@person.nil? && @person.save
            format.html {
              flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Person', locale: DataCycleCore.ui_language
              redirect_to @person
             }
            format.js
          else
            redirect_back(fallback_location: root_path)
            return
          end
        end
      end
    end

    def edit
      @content = DataCycleCore::Person.find(params[:id])
      I18n.with_locale(params[:locale]) do
        @content.save
      end if params[:locale] && !@content.translated_locales.include?(params[:locale])

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        @dataSchema = @content.get_data_hash
        render 'edit'
      end
    end

    def update
      @person = DataCycleCore::Person.find(params[:id])
      I18n.with_locale(@person.first_available_locale(params[:locale])) do
        object_params = person_params('persons', @person.metadata['validation']['name'], @person.metadata['validation']['description'])
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],@person.metadata['validation'], false)

        valid = @person.set_data_hash(data_hash: datahash, current_user: current_user)

        if valid.key?(:error) && !valid[:error].empty?
          flash[:error] = valid[:error]
          redirect_to edit_person_path(@person)
          return
        end

        if @person.save
          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Person', locale: DataCycleCore.ui_language

          if Rails.env.development?
            redirect_back(fallback_location: root_path)
          else
            redirect_to person_path(@person, watch_list_id: @watch_list)
          end

        else
          render 'edit'
        end
      end
    end

    def destroy
      @person = DataCycleCore::Person.find(params[:id])
      @person.destroy_content
      @person.destroy

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Person', locale: DataCycleCore.ui_language

      redirect_to persons_path
    end

    def validate_single_data
      @person = DataCycleCore::Person.find(params[:id])

      object_params = person_params('persons', @person.metadata['validation']['name'], @person.metadata['validation']['description'])

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],@person.metadata['validation'])
      valid = @person.validate(datahash)

      render :json => valid.to_json
    end

    private

      def create_params
      end

      def person_params(storage_location, template_name, template_description)
        datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name, template_description)
        params.require(:person).permit(:datahash => datahash)
      end
  end
end
