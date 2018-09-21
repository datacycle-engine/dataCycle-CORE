# frozen_string_literal: true

module DataCycleCore
  class ContentsController < ApplicationController
    DataCycleCore.features.each_key do |key|
      module_name = ('DataCycleCore::Feature::ControllerFunctions::' + key.to_s.classify).constantize
      include module_name if ('DataCycleCore::Feature::' + key.to_s.classify).constantize.enabled?
    end

    before_action :authenticate_user!, :set_watch_list
    load_and_authorize_resource only: [:index, :show, :destroy, :history]
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    def index
      redirect_back(fallback_location: root_path)
    end

    def show
      @content = data_cycle_object(controller_name).find(params[:id])

      redirect_back(fallback_location: root_path) && return if @content.nil?

      if DataCycleCore::Feature::Container.enabled? &&
         @content.content_type?('entity') &&
         !['Bild', 'Video', 'Video-Serie', 'Foto-Serie'].include?(@content.template_name)
        I18n.with_locale(DataCycleCore.ui_language) do
          @parents = DataCycleCore::CreativeWork.where("schema ->> 'content_type' = 'container' AND template = FALSE").includes(:translations).map { |c| [c.title, c.id] }.presence&.to_h
        end
      end

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        if DataCycleCore::Feature::Container.enabled? && @content.content_type?('container')
          @filters = params[:f].presence&.values&.reject { |f| f['v'].blank? } || []
          @filters.push(
            {
              't' => 'part_of',
              'v' => @content.id
            }
          )

          @language ||= params.fetch(:language, ['all'])
          if @content.children.present?
            @paginate_object = get_filtered_results
            @total = @paginate_object.count_distinct
            @paginate_object = @paginate_object.distinct_by_content_id(@order_string).content_includes.page(params[:page])
            @total_pages = (@total.to_f / 25).ceil
            @contents = @paginate_object.map(&:content_data)
          end

          @entities = DataCycleCore::CreativeWork.where("template = ? AND schema ->> 'content_type' = ?", true, 'entity').order(:template_name)
          @entities = @entities.where('template_name NOT IN(?)', DataCycleCore.excluded_filter_classifications + DataCycleCore.excluded_new_item_objects)
          @entities = DataCycleCore::Feature::Container.apply_allowed_contents(@content, @entities)
          @entities = DataCycleCore::Feature::Container.apply_excluded_contents(@content, @entities)
        end

        respond_to do |format|
          format.json { redirect_to polymorphic_path([:api, :v2, @content]) }
          format.html { render && return }
        end
      end
    end

    def create
      if params[:source] == 'object_browser'
        authorize!(:create_in_objectbrowser, data_cycle_object(controller_name))
      else
        authorize!(:create, data_cycle_object(controller_name))
      end

      I18n.with_locale(locale_params[:locale]) do
        object_params = content_params(controller_name, params[:template])

        if source_params.present?
          source = data_cycle_object(source_params[:source_table]).find_by(id: source_params[:source_id])
        else
          source = data_cycle_object(controller_name).find_by(id: parent_params[:parent_id])
        end

        @content = DataCycleCore::DataHashService.create_internal_object(controller_name, params[:template], object_params, current_user, parent_params[:parent_id], source)

        redirect_back(fallback_location: root_path) && return if @content.nil?

        # after_create(@content, current_user)

        respond_to do |format|
          if @content.present?
            execute_after_create_webhooks @content
            format.html do
              redirect_to edit_polymorphic_path(@content, source_params.merge(watch_list_params)), notice: I18n.t(:created, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language)
            end
            format.js
          else
            redirect_back(fallback_location: root_path)
          end
        end
      end
    end

    def edit
      @content = data_cycle_object(controller_name).find(params[:id])

      # get show data for split view
      if source_params.present?
        @split_source = data_cycle_object(source_params[:source_table]).find(source_params[:source_id])
        @split_schema = []

        if @split_source.present?
          I18n.with_locale(@split_source.first_available_locale) do
            @split_schema = @split_source.get_data_hash
          end
        end
      end

      if params[:locale] &&
         !@content.translated_locales.include?(params[:locale]&.to_sym) &&
         I18n.available_locales.include?(params[:locale]&.to_sym) &&
         (DataCycleCore.translatable_types & [@content.class.name, @content.template_name]).present?
        I18n.with_locale(params[:locale]) do
          @content.save
        end
      end

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        redirect_to(polymorphic_path(@content), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return unless can?(:edit, @content)

        render && return
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
        @content.finalize = params[:finalize]

        valid = @content.set_data_hash(data_hash: datahash, current_user: current_user)

        redirect_to(edit_polymorphic_path(@content, watch_list_params), alert: valid[:error]) && return if valid[:error].present?

        execute_after_update_webhooks @content

        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language

        if Rails.env.development?
          redirect_back(fallback_location: root_path)
        else
          redirect_to(polymorphic_path(@content, watch_list_params))
        end
      end
    end

    def destroy
      @content = data_cycle_object(controller_name).find(params[:id])
      @content.destroy_content(current_user: current_user)

      execute_after_destroy_webhooks @content

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language

      redirect_to(polymorphic_path(@content.parent, watch_list_params)) && return if @content.try(:parent).present?

      redirect_to root_path
    end

    def compare
      @content = data_cycle_object(controller_name).includes(:classifications).find(params[:id])
      authorize! :show, @content

      redirect_back(fallback_location: root_path, alert: (I18n.t :no_source, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if source_params.blank?

      @diff_source = data_cycle_object(source_params[:source_table]).find(source_params[:source_id])

      redirect_back(fallback_location: root_path) && return if @diff_source.nil? || @content.nil?

      I18n.with_locale(@content.first_available_locale) do
        @data_schema = @content.get_data_hash
      end

      I18n.with_locale(@diff_source.first_available_locale) do
        @diff_schema = @diff_source.diff(@data_schema)
      end
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

    def import
      content = params[:data].as_json
      external_source = DataCycleCore::ExternalSource.find(content['source_key'])
      api_strategy_class = DataCycleCore.allowed_api_strategies.find { |object| object == external_source.config['api_strategy'] }
      api_strategy = api_strategy_class&.constantize&.new(external_source, 'creative_work', content.values.first['url'].split('/').last)
      @content = api_strategy.create(content.except('source_key'))
      @content = @content.try(:first)

      respond_to do |format|
        format.js do
          if params[:render_html]
            flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language
            render js: "document.location = '#{polymorphic_path(@content)}'"
          end
        end
      end
    end

    def set_parent
      @content = data_cycle_object(controller_name).find(params[:id])
      authorize! :edit, @content

      redirect_back(fallback_location: root_path, alert: I18n.t(:invalid_parent, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if parent_params[:parent_id].blank?

      @parent = data_cycle_object(controller_name).find(parent_params[:parent_id])

      I18n.with_locale(@content.first_available_locale) do
        if @content.update_column(:is_part_of, @parent.id)
          redirect_back(fallback_location: root_path, notice: I18n.t(:moved_to, scope: [:controllers, :success], locale: DataCycleCore.ui_language, data: @parent.title))
        else
          redirect_back(fallback_location: root_path, alert: @content.errors.full_messages)
        end
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

    def watch_list_params
      { watch_list_id: @watch_list&.id }
    end

    def locale_params
      I18n.available_locales.include?(params[:locale].try(:to_sym)) ? params.permit(:locale) : { locale: I18n.locale.to_s }
    end

    def parent_params
      params.permit(:parent_id)
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
        ActionController::Parameters.new(Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }]).permit(:source_id, :source_table)
      elsif params[:source_id] && params[:source_table]
        params.permit(:source_id, :source_table)
      else
        {}
      end
    end
  end
end
