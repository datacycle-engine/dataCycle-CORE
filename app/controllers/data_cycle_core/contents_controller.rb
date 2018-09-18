# frozen_string_literal: true

module DataCycleCore
  class ContentsController < ApplicationController
    before_action :authenticate_user!, :set_watch_list
    load_and_authorize_resource only: [:index, :show, :destroy, :history]
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    after_action :notify_subscribers, only: :update

    def index
      redirect_back(fallback_location: root_path)
    end

    def show
      @content = data_cycle_object(controller_name).find(params[:id])

      redirect_back(fallback_location: root_path) && return if @content.nil?
      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        respond_to do |format|
          format.json { redirect_to polymorphic_path([:api, :v2, @content]) }
          format.html { render }
        end
      end
    end

    def create
      if params[:source] == 'object_browser'
        authorize!(:create_in_objectbrowser, data_cycle_object(controller_name))
      else
        authorize!(:create, data_cycle_object(controller_name))
      end

      locale = I18n.available_locales.include?(params[:locale].try(:to_sym)) ? params[:locale].try(:to_sym) : I18n.locale
      I18n.with_locale(locale) do
        source = Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }] if params[:source].present?
        object_params = content_params(controller_name, params[:template])
        @content = DataCycleCore::DataHashService.create_internal_object(controller_name, params[:template], object_params, current_user)

        redirect_back(fallback_location: root_path) && return if @content.nil?

        respond_to do |format|
          # validate ?
          if !@content.nil? && @content.save
            execute_after_create_webhooks @content
            format.html do
              flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language
              redirect_to(edit_polymorphic_path(@content, (source || {}).merge(watch_list_id: @watch_list))) && return
            end
            format.js
          else
            redirect_back(fallback_location: root_path) && return
          end
        end
      end
    end

    def edit
      @content = data_cycle_object(controller_name).find(params[:id])

      # get show data for split view
      if source_params.present?
        @split_type = source_params[:source_type].constantize
        @split_source = @split_type.find(source_params[:source_id])
        @split_schema = []

        unless @split_source.nil?
          I18n.with_locale(@split_source.first_available_locale) do
            @split_schema = @split_source.get_data_hash
          end
        end
      end

      if params[:locale] && !@content.translated_locales.include?(params[:locale]&.to_sym) && I18n.available_locales.include?(params[:locale]&.to_sym) && (DataCycleCore.translatable_types & [@content.class.name, @content.template_name]).present?
        I18n.with_locale(params[:locale]) do
          @content.save
        end
      end

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        redirect_to(polymorphic_path(@content), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return unless can?(:edit, @content)

        render
      end
    end

    def edit_by_external_key
      return if params[:external_key].blank?

      @content = data_cycle_object(controller_name).find_by(external_key: params[:external_key])
      authorize!(:edit, @content)

      redirect_to edit_polymorphic_path(@content)
    end

    def update
      @content = data_cycle_object(controller_name).find(params[:id])
      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        redirect_to(polymorphic_path(@content), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return unless can?(:update, @content)

        object_params = content_params(controller_name, @content.template_name)
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @content.schema)

        # datahash = before_set_data_hash(datahash)

        # data_hash_has_changes = DataCycleCore::DataHashService.data_hash_is_dirty?(
        #   datahash.merge({ 'id' => @content.id }),
        #   @content.get_data_hash
        # )

        # unless data_hash_has_changes
        #   flash[:info] = I18n.t :not_modified, scope: [:controllers, :info], data: @content.template_name, locale: DataCycleCore.ui_language
        #   if (Rails.env.development? || params[:splitview]) && !params[:finalize]
        #     redirect_back(fallback_location: root_path)
        #   else
        #     redirect_to polymorphic_path(@content, watch_list_id: @watch_list)
        #   end
        #   return
        # end

        valid = @content.set_data_hash(data_hash: datahash.merge(release_params), current_user: current_user)

        redirect_to(edit_creative_work_path(@content, watch_list_id: @watch_list), alert: valid[:error]) && return if valid[:error].present?

        execute_after_update_webhooks @content

        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language

        if Rails.env.development?
          redirect_back(fallback_location: root_path) && return
        else
          redirect_to(polymorphic_path(@content, watch_list_id: @watch_list)) && return
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
      @diff_source = @content.histories.find(params[:history_id]) if params[:history_id].present?

      redirect_back(fallback_location: root_path) && return if @diff_source.nil? || @content.nil?

      I18n.with_locale(@content.first_available_locale) do
        @data_schema = @content.get_data_hash
      end

      I18n.with_locale(@diff_source.first_available_locale) do
        @diff_schema = @diff_source.diff(@data_schema)
      end
    end

    def new_embedded_object
      objects_class = data_cycle_object(params.dig(:definition, 'linked_table'))
      @content = data_cycle_object(controller_name).find(params[:id])

      return unless can?(:edit, objects_class) || can?(:edit, @content)

      respond_to(:js)
    end

    # only used in split-view
    def render_embedded_object
      objects_class = data_cycle_object(params.dig(:definition, 'linked_table'))
      authorize! :edit, objects_class

      @objects = objects_class.where(id: params[:object_ids]).includes(:translations)
      @content = data_cycle_object(controller_name).find(params[:id])

      respond_to(:js)
    end

    def gpx
      @object = data_cycle_object(controller_name).find_by(id: params[:id])
      authorize! :show, @object
      send_data @object.create_gpx, filename: "#{@object.title.blank? ? 'unnamed_place' : @object.title.underscore.parameterize(separator: '_')}.gpx", type: 'gpx/xml'
    end

    def update_life_cycle_stage
      @object = data_cycle_object(controller_name).find_by(id: params[:id])
      authorize! :edit, @object

      # Create idea_collection if it doesn't exist and active life_cycle_stage is correct
      if DataCycleCore::Feature::IdeaCollection.enabled? &&
         @object.content_type?('container') &&
         DataCycleCore::Feature::LifeCycle.ordered_classifications.dig(DataCycleCore::Feature::IdeaCollection.life_cycle_stage, :id) == life_cycle_params[:id] &&
         !@object.children.where(template_name: DataCycleCore::Feature::IdeaCollection.template).exists?
        idea_collection_params = ActionController::Parameters.new({ datahash: { headline: @object.headline } }).permit!
        idea_collection = DataCycleCore::DataHashService.create_internal_object(controller_name, DataCycleCore::Feature::IdeaCollection.template, idea_collection_params, current_user)
        idea_collection.is_part_of = @object.id unless @object.nil?
        idea_collection.save
      end

      @object.set_life_cycle_classification(DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(@object).presence&.first, life_cycle_params[:id], current_user)

      redirect_back(fallback_location: root_path, notice: (I18n.t :moved_to, scope: [:controllers, :success], data: life_cycle_params[:name], locale: DataCycleCore.ui_language))
    end

    def validate
      @object = data_cycle_object(controller_name).find_by(id: params[:id])

      if @object.blank? && params[:template].present?
        @object = data_cycle_object(controller_name).find_by(template: true, template_name: params[:template])
      end

      render json: { warning: { content: ['content/template not found'] } } && return if @object.blank?

      authorize! :show, @object

      object_params = content_params(controller_name, @object.template_name)
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @object.schema)
      valid = @object.validate(datahash)
      render json: valid.to_json
    end

    def load_more_linked_objects
      @content = data_cycle_object(linked_object_params[:content_type]).find(linked_object_params[:content_id]) if linked_object_params[:content_type].present?
      @object = data_cycle_object(controller_name).find(linked_object_params[:id])
      authorize! :show, @object

      @page = linked_object_params.fetch(:page, 1)

      if linked_object_params[:load_more_type] == 'all'
        @linked_objects = @object.try(linked_object_params[:key])&.where&.not(id: linked_object_params[:load_more_except])&.includes(:translations)
      else
        @linked_objects = @object.try(linked_object_params[:key])&.includes(:translations)&.page(@page)&.per(DataCycleCore.linked_objects_page_size)
      end

      @params = linked_object_params.to_h

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

    def upload
      return if asset_params[:file].blank?
      object_type = DataCycleCore.asset_objects.find { |object| object.downcase.include?(asset_params[:file].content_type&.split('/')&.first&.downcase) }

      render(json: { error: I18n.t(:wrong_content_type, scope: [:controllers, :error], locale: DataCycleCore.ui_language) }) && return if object_type.blank?

      authorize! :create, object_type.constantize

      @asset = object_type.constantize.new(asset_params).set_content_type.set_file_size
      @asset.name = asset_params[:file].original_filename if asset_params[:name].blank?
      @asset.creator_id = current_user.try(:id)
      @asset.save

      errors = MediaArchive::Webhooks::Create.new.execute(@asset)
      render(json: { error: JSON.parse(errors)['errors'] }) && return if errors.present? && JSON.parse(errors).key?('errors')

      render json: @asset
    end

    def catch_all
      @object = data_cycle_object(controller_name).find(params[:id])

      raise(ActionController::RoutingError, 'Not Found') unless @object.enabled_features.map { |f| "data_cycle_core/feature/#{f}".classify.constantize.controller_functions.map(&:to_s) }.flatten.include?(params['path']) && respond_to?(params['path'])

      send(path_params['path'])
    end

    def record_not_found
      raise DataCycleCore::Error::RecordNotFoundError, 'DataCycle Record Not Found'
    end

    private

    def execute_after_update_webhooks(data)
    end

    def execute_after_create_webhooks(data)
    end

    def execute_after_destroy_webhooks(data)
    end

    def set_watch_list
      watch_list = DataCycleCore::WatchList.find(params[:watch_list_id]) if params[:watch_list_id]
      @watch_list = watch_list if can?(:manage, watch_list)
    end

    def path_params
      params.permit(:path)
    end

    def release_params
      params.require(controller_name.singularize.to_sym).permit(release: [:release_id, :release_comment])
    end

    def asset_params
      params.permit(:file)
    end

    def linked_object_params
      params.permit(:id, :key, :page, :load_more_action, :locale, :load_more_type, :complete_key, :editable, :content_id, :content_type, definition: {}, load_more_except: [], options: {})
    end

    def life_cycle_params
      params.require(:life_cycle).permit(:name, :id)
    end

    def content_params(storage_location, template_name)
      datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name)
      params.require(controller_name.singularize.to_sym).permit(datahash: datahash)
    end

    def source_params
      if params[:source]
        ActionController::Parameters.new(Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }]).permit(:source_id, :source_type)
      elsif params[:source_id] && params[:source_type]
        params.permit(:source_id, :source_type)
      end
    end

    def notify_subscribers
      @content.subscriptions.except_user(current_user).to_notify.presence&.each do |subscription|
        DataCycleCore::SubscriptionMailer.notify(subscription.user, [@content]).deliver_later
      end
    end
  end
end
