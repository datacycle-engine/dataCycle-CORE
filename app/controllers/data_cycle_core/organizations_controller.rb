module DataCycleCore
  class OrganizationsController < ContentsController
    before_action :authenticate_user!   # from devise (authenticate)
    load_and_authorize_resource         # from cancancan (authorize)

    def index
      @paginateObject = DataCycleCore::Organization.all.where(template: false).order(updated_at: :desc).page(params[:page])
      @organization = DataCycleCore::Organization.new
    end

    def show
      @content = DataCycleCore::Organization.find_by(id: params[:id])

      redirect_back(fallback_location: root_path) && return if @content.nil?

      I18n.with_locale(@content.first_available_locale) do
        @dataSchema = @content.get_data_hash

        respond_to do |format|
          format.json { redirect_to api_v1_content_path(type: 'organizations', id: params[:id]) }
          format.html { render 'show' }
        end
      end
    end

    def create
      I18n.with_locale(params[:locale] || I18n.locale) do
        object_params = organization_params('organizations', params[:template])
        @organization = DataCycleCore::DataHashService.create_internal_object('organizations', params[:template], object_params, current_user)

        if @organization.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        respond_to do |format|
          # validate ?
          if !@organization.nil? && @organization.save
            format.html do
              flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @organization.template_name, locale: DataCycleCore.ui_language
              redirect_to @organization
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
      @content = DataCycleCore::Organization.find(params[:id])

      if params[:locale] && !@content.translated_locales.include?(params[:locale]) && I18n.available_locales.include?(params[:locale]&.to_sym) && (DataCycleCore.translatable_types & [@content.class.name, @content.template_name]).present?
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
      @organization = DataCycleCore::Organization.find(params[:id])
      I18n.with_locale(@organization.first_available_locale(params[:locale])) do
        object_params = organization_params('organizations', @organization.template_name)
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @organization.schema, false)

        valid = @organization.set_data_hash(data_hash: datahash, current_user: current_user)

        if valid.key?(:error) && !valid[:error].empty?
          flash[:error] = valid[:error]
          redirect_to edit_organization_path(@organization)
          return
        end

        if @organization.save
          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Organization', locale: DataCycleCore.ui_language

          if Rails.env.development?
            redirect_back(fallback_location: root_path)
          else
            redirect_to organization_path(@organization, watch_list_id: @watch_list)
          end

        else
          render 'edit'
        end
      end
    end

    def destroy
      @organization = DataCycleCore::Organization.find(params[:id])
      @organization.destroy_content
      @organization.destroy

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Organization', locale: DataCycleCore.ui_language

      redirect_to organizations_path
    end

    def validate_single_data
      @organization = DataCycleCore::Organization.find(params[:id])

      object_params = organization_params('organizations', @organization.template_name)

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @organization.schema)
      valid = @organization.validate(datahash)

      render json: valid.to_json
    end

    private

    def create_params
    end

    def organization_params(storage_location, template_name)
      datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name)
      params.require(:organization).permit(datahash: datahash)
    end
  end
end
