module DataCycleCore
  class ContentsController < ApplicationController
    before_action :authenticate_user!, :set_watch_list
    load_and_authorize_resource only: [:index, :show, :edit, :update, :create, :destroy, :history]

    def index
      redirect_back(fallback_location: root_path)
    end

    def show
      @content = data_cycle_object(controller_name).find_by(id: params[:id])

      redirect_back(fallback_location: root_path) && return if @content.nil?

      I18n.with_locale(@content.first_available_locale) do
        respond_to do |format|
          format.json { redirect_to api_v1_content_path(type: controller_name, id: params[:id]) }
          format.html { render 'show' }
        end
      end
    end

    def create
      locale = I18n.available_locales.include?(params[:locale].try(:to_sym)) ? params[:locale].try(:to_sym) : I18n.locale
      I18n.with_locale(locale) do
        object_params = content_params(controller_name, params[:template])
        @content = DataCycleCore::DataHashService.create_internal_object(controller_name, params[:template], object_params, current_user)

        if @content.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        respond_to do |format|
          # validate ?
          if !@content.nil? && @content.save
            execute_after_create_webhooks @content
            format.html do
              flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language
              redirect_to edit_polymorphic_path @content
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
      @content = data_cycle_object(controller_name).find_by(id: params[:id])

      if params[:locale] && !@content.translated_locales.include?(params[:locale]) && I18n.available_locales.include?(params[:locale]&.to_sym) && (DataCycleCore.translatable_types & [@content.class.name, @content.template_name]).present?
        I18n.with_locale(params[:locale]) do
          @content.save
        end
      end

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        render 'edit'
      end
    end

    def update
      @content = data_cycle_object(controller_name).find(params[:id])
      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        object_params = content_params(controller_name, @content.template_name)
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @content.schema)

        datahash = before_set_data_hash(datahash)

        data_hash_has_changes = DataCycleCore::DataHashService.data_hash_is_dirty?(
          datahash.merge({ 'id' => @content.id }),
          @content.get_data_hash
        )

        unless data_hash_has_changes
          flash[:info] = I18n.t :not_modified, scope: [:controllers, :info], data: @content.template_name, locale: DataCycleCore.ui_language
          if (Rails.env.development? || params[:splitview]) && !params[:finalize]
            redirect_back(fallback_location: root_path)
          else
            redirect_to polymorphic_path(@content, watch_list_id: @watch_list)
          end
          return
        end

        valid = @content.set_data_hash(data_hash: datahash, current_user: current_user)

        if valid.key?(:error) && !valid[:error].empty?
          flash[:error] = valid[:error]
          redirect_to edit_polymorphic_path(@content)
          return
        end

        if @content.save
          execute_after_update_webhooks @content

          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language

          if Rails.env.development?
            redirect_back(fallback_location: root_path)
          else
            redirect_to polymorphic_path(@content, watch_list_id: @watch_list)
          end

        else
          render 'edit'
        end
      end
    end

    def destroy
      @content = data_cycle_object(controller_name).find(params[:id])
      @content.destroy_content
      @content.destroy

      execute_after_destroy_webhooks @content

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language

      redirect_to root_path
    end

    def history
      @content = data_cycle_object(controller_name).includes(:classifications).find(params[:id])

      @history_source = @content.histories.find(params[:history_id]) unless params[:history_id].nil?

      unless @history_source.nil?
        I18n.with_locale(@history_source.first_available_locale) do
          @history_schema = @history_source.get_data_hash
        end
      end

      I18n.with_locale(@content.first_available_locale) do
        @data_schema = @content.get_data_hash
        @diff_schema = helpers.get_diff(@history_schema.merge(@history_source.releasable_hash), @data_schema.merge(@content.releasable_hash))
      end
    end

    def history_detail
      history
    end

    def new_embedded_object
      @object = @objects = data_cycle_object(params[:definition]['linked_table'])
      authorize! :edit, @object
      respond_to(:js)
    end

    def render_embedded_object
      @object = data_cycle_object(params[:definition]['linked_table'])
      authorize! :edit, @object
      @objects = @object.where(id: params[:id]).includes(:translations)
      respond_to(:js)
    end

    def gpx
      @object = data_cycle_object(controller_name).find_by(id: params[:id])
      authorize! :show, @object
      send_data @object.create_gpx, filename: "#{@object.title.blank? ? 'unnamed_place' : @object.title.underscore.parameterize(separator: '_')}.gpx", type: 'gpx/xml'
    end

    def set_life_cycle
      @object = data_cycle_object(controller_name).find_by(id: params[:id])
      authorize! :edit, @object

      # Create idea_collection if it doesn't exist and active life_cycle_stage is correct
      if DataCycleCore::Feature::Container.enabled? && @object.content_type?('container') && helpers.life_cycle_items.dig(DataCycleCore.features.dig(:life_cycle, :idea_collection, :life_cycle_stage), :id) == life_cycle_params[:id] && !@object.children.where(template_name: DataCycleCore.features.dig(:life_cycle, :idea_collection, :life_cycle_stage)).exists?
        idea_collection_params = ActionController::Parameters.new({ datahash: { headline: @object.headline } }).permit!
        idea_collection = DataCycleCore::DataHashService.create_internal_object(object_type, DataCycleCore.features.dig(:life_cycle, :idea_collection, :life_cycle_stage), idea_collection_params, current_user)
        idea_collection.is_part_of = @object.id unless @object.nil?
        idea_collection.save
      end

      @object.set_classification_with_children(DataCycleCore.features.dig(:life_cycle, :attribute_key), life_cycle_params[:id], current_user)

      redirect_back(fallback_location: root_path, notice: (I18n.t :moved_to, scope: [:controllers, :success], data: life_cycle_params[:name], locale: DataCycleCore.ui_language))
    end

    def validate
      @object = data_cycle_object(controller_name).find_by(id: params[:id])
      authorize! :show, @object

      if @object.blank? && params[:template].present?
        @object = data_cycle_object(controller_name).find_by(template: true, template_name: params[:template])
      end

      render json: { warning: { content: ['content/template not found'] } } && return if @object.blank?

      object_params = content_params(controller_name, @object.template_name)
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @object.schema)
      valid = @object.validate(datahash)
      render json: valid.to_json
    end

    def load_more_linked_objects
      @object = data_cycle_object(controller_name).find(linked_object_params[:id])
      authorize! :show, @object

      @page = linked_object_params.fetch(:page, 1)

      if linked_object_params[:load_more_type] == 'all'
        @linked_objects = @object.try(linked_object_params[:key])&.where&.not(id: linked_object_params[:load_more_except])&.includes(:translations)
      else
        @linked_objects = @object.try(linked_object_params[:key])&.includes(:translations)&.page(@page)&.per(DataCycleCore.linked_objects_page_size)
      end

      respond_to do |format|
        format.js do
          if linked_object_params[:load_more_action] == 'object_browser'
            render :load_more_linked_objects_object_browser
          elsif linked_object_params[:load_more_action] == 'embedded_object'
            render :load_more_linked_objects_embedded_object
          else
            render :load_more_linked_objects_show
          end
        end
      end
    end

    private

    def data_cycle_object(object_string)
      object_type = DataCycleCore.content_tables.find { |object| object == object_string }
      ('DataCycleCore::' + object_type.singularize.classify).constantize
    end

    def execute_after_update_webhooks(data)
    end

    def execute_after_create_webhooks(data)
    end

    def execute_after_destroy_webhooks(data)
    end

    def before_set_data_hash(datahash)
      datahash
    end

    def set_watch_list
      watch_list = DataCycleCore::WatchList.find(params[:watch_list_id]) if params[:watch_list_id]
      @watch_list = watch_list if can?(:manage, watch_list)
    end

    def linked_object_params
      params.permit(:id, :key, :page, :load_more_action, :load_more_type, load_more_except: [])
    end

    def life_cycle_params
      params.require(:life_cycle).permit(:name, :id)
    end

    def content_params(storage_location, template_name)
      datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name)
      params.require(controller_name.singularize.to_sym).permit(:release_id, :release_comment, datahash: datahash)
    end
  end
end
