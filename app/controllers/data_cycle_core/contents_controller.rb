# frozen_string_literal: true

module DataCycleCore
  class ContentsController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user!, except: [:asset]
    before_action :set_watch_list, except: [:asset]

    DataCycleCore.features.select { |_, v| !v.dig(:only_config) == true }.each_key do |key|
      feature = ('DataCycleCore::Feature::' + key.to_s.classify).constantize
      include feature.controller_module if feature.enabled? && feature.controller_module
    end

    load_and_authorize_resource only: [:index, :show, :destroy, :history]

    def index
      redirect_back(fallback_location: root_path)
    end

    def bulk_create
      new_thing_params = params.dig('thing')

      return if new_thing_params.blank?

      item_count = new_thing_params.keys.size
      index = 0
      content_ids = []

      ActionCable.server.broadcast "bulk_create_#{params[:overlay_id]}_#{current_user.id}", progress: 0, items: item_count

      new_thing_params.each do |_key, thing_params|
        thing_hash = content_params(params[:template], thing_params)

        I18n.with_locale(create_locale(thing_params)) do
          content = DataCycleCore::DataHashService.create_internal_object(params[:template], thing_hash, current_user)
          content_ids << { id: content.id, field_id: thing_params[:uploader_field_id] } if content.try(:id).present?

          ActionCable.server.broadcast "bulk_create_#{params[:overlay_id]}_#{current_user.id}", progress: index += 1, items: item_count, errors: content.try(:errors).presence
        end
      end

      flash.now[:success] = I18n.t :bulk_created, scope: [:controllers, :success], count: item_count, locale: DataCycleCore.ui_language

      ActionCable.server.broadcast "bulk_create_#{params[:overlay_id]}_#{current_user.id}", redirect_path: root_path, flash: flash.to_hash, created: true, content_ids: content_ids

      head(:ok)
    end

    def show
      @content = DataCycleCore::Thing.find(params[:id])

      redirect_back(fallback_location: root_path) && return if @content.nil?

      if DataCycleCore::Feature::Container.enabled? &&
         @content.content_type?('entity') &&
         @content.instance_of?(DataCycleCore::Thing) &&
         !['Bild', 'Video', 'Video-Serie', 'Foto-Serie'].include?(@content.template_name)
        I18n.with_locale(DataCycleCore.ui_language) do
          @parents = DataCycleCore::Thing.where("schema ->> 'content_type' = 'container' AND template = FALSE").includes(:translations).map { |c| [c.title, c.id] }.presence&.to_h
        end
      end

      I18n.with_locale(@locale = @content.first_available_locale(params[:locale])) do
        if DataCycleCore::Feature::Container.enabled? && @content.content_type?('container')
          pre_filters
          @pre_filters.push(
            {
              't' => 'part_of',
              'v' => @content.id
            }
          )

          @language ||= params.fetch(:language) { ['all'] }
          set_instance_variables_by_view_mode(query: @query, user_filter: { scope: 'show', template_name: @content.template_name })
        end

        respond_to do |format|
          format.json { redirect_to send("api_#{DataCycleCore.main_config.dig(:api, :default)}_thing_path", id: @content) }
          format.js { render 'data_cycle_core/application/more_results' }
          format.html { render && return }
        end
      end
    end

    # original = content_url
    # content => Bild: content_url ; other = thumbnail_url
    # thumbnail = thumbnail_url
    def asset
      content = DataCycleCore::Thing.find(params[:id])
      type = asset_proxy_params.dig(:type)
      attribute = :content_url
      attribute = :thumbnail_url if type == 'thumb' || (type == 'content' && content.template_name != 'Bild')

      raise ActiveRecord::RecordNotFound unless content.respond_to?(attribute)
      uri = URI.parse(content.send(attribute))

      redirect_to(uri.to_s)
    end

    def new
      @resolved_params = resolve_params(new_params)
      @template = DataCycleCore::Thing.find_by(template: true, template_name: @resolved_params[:template])

      return if @template.nil?

      respond_to :js
    end

    def create
      authorize!(__method__, DataCycleCore::Thing.find_by(template: true, template_name: params[:template]), resolve_params(params, false).dig(:scope))

      @object_browser_parent = DataCycleCore::Thing.find_by(id: params[:content_id]) || DataCycleCore::Thing.new { |t| t.id = params[:content_id] } if params[:content_id].present?

      I18n.with_locale(create_locale) do
        object_params = content_params(params[:template])

        if source_params.present?
          source = DataCycleCore::Thing.find_by(id: source_params[:source_id])
        else
          source = DataCycleCore::Thing.find_by(id: parent_params[:parent_id])
        end

        @content = DataCycleCore::DataHashService.create_internal_object(params[:template], object_params, current_user, parent_params[:parent_id], source)

        redirect_back(fallback_location: root_path) && return if @content.try(:errors).present?

        respond_to do |format|
          if @content.present?
            format.html do
              redirect_to edit_thing_path(@content, source_params.merge(watch_list_params)), notice: I18n.t(:created, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language)
            end
            format.js
          else
            redirect_back(fallback_location: root_path)
          end
        end
      end
    end

    def edit
      @content ||= DataCycleCore::Thing.find(params[:id])
      @hide_embedded = params[:hide_embedded].present?

      # get show data for split view
      if source_params.present?
        @split_source = DataCycleCore::Thing.find(source_params[:source_id])
        @source_locale = source_params[:source_locale]
      end

      I18n.with_locale(params[:locale] || @content.first_available_locale) do
        @locale = I18n.locale
        authorize!(:edit, @content)

        render && return
      end
    end

    def edit_by_external_key
      return if params[:external_key].blank?

      @content = DataCycleCore::Thing.find_by(external_key: params[:external_key])
      authorize!(:edit, @content)

      redirect_to edit_thing_path(@content, watch_list_params)
    end

    def split_view
      @content = DataCycleCore::Thing.find(params[:id])
      @split_source = DataCycleCore::Thing.find(source_params[:source_id])
      @source_locale = source_params[:source_locale]

      I18n.with_locale(params[:locale] || @content.first_available_locale) do
        @locale = I18n.locale
        authorize!(:edit, @content)

        render(:edit) && return
      end
    end

    def update
      @content ||= DataCycleCore::Thing.find(params[:id])
      I18n.with_locale(params[:locale] || @content.first_available_locale) do
        authorize!(:update, @content)

        object_params = content_params(@content.template_name)
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @content.schema)
        @content.finalize = params[:finalize] if DataCycleCore::Feature::Releasable.enabled?
        valid = @content.set_data_hash(data_hash: datahash, current_user: current_user, partial_update: true, version_name: object_params[:version_name])

        if valid[:error].present?
          flash[:error] = valid[:error]
          redirect_back(fallback_location: root_path)
          return
        end

        if valid[:warning].present?
          flash[:info] = valid[:warning]
        else
          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language
        end

        duplicate = params[:duplicate_id].present? && self.class.method_defined?(:merge_and_remove_duplicate)
        merge_and_remove_duplicate if duplicate

        if params[:new_locale].present?
          redirect_to(edit_thing_path(@content, watch_list_params.merge(locale: params[:new_locale])))
        elsif !params[:save_and_close] && !params[:finalize] && !duplicate
          redirect_back(fallback_location: root_path)
        else
          redirect_to(thing_path(@content, watch_list_params.merge(locale: I18n.locale)))
        end
      end
    end

    def destroy
      @content = DataCycleCore::Thing.find(params[:id])

      I18n.with_locale(@content.first_available_locale(destroy_params[:locale])) do
        destroy_content_params = { current_user: current_user }
        if @content.external_source_id.present?
          destroy_content_params[:save_history] = true
          destroy_content_params[:destroy_linked] = true
        end

        destroy_content_params[:destroy_locale] = destroy_params[:locale].present?

        @content.destroy_content(destroy_content_params)

        flash[:success] = @content.destroyed? ? I18n.t(:destroyed, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language) : I18n.t(:destroyed_translation, scope: [:controllers, :success], data: @content.template_name, language: I18n.locale, locale: DataCycleCore.ui_language)

        redirect_to(thing_path(@content, watch_list_params)) && return unless @content.destroyed?
        redirect_to(thing_path(@content.parent, watch_list_params)) && return if @content.try(:parent).present?
        redirect_to root_path
      end
    end

    def compare
      @content = DataCycleCore::Thing.includes(:classifications).find(params[:id])
      authorize! :show, @content

      redirect_back(fallback_location: root_path, alert: (I18n.t :no_source, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if source_params.blank?

      @diff_source = DataCycleCore::Thing.find(source_params[:source_id])

      redirect_back(fallback_location: root_path) && return if @diff_source.nil? || @content.nil?

      I18n.with_locale(@content.first_available_locale) do
        @data_schema = @content.get_data_hash
      end

      I18n.with_locale(@diff_source.first_available_locale) do
        @diff_schema = @diff_source.diff(@data_schema)
      end
    end

    def history
      @content = DataCycleCore::Thing.includes(:classifications).find(params[:id])
      @diff_source = @content.histories.find(params[:history_id]) if params[:history_id].present?

      redirect_back(fallback_location: root_path) && return if @diff_source.nil? || @content.nil?

      I18n.with_locale(@diff_source.first_available_locale) do
        @data_schema = @content.get_data_hash
        @diff_schema = @diff_source.diff(@data_schema)
      end
    end

    def import
      content = params[:data].as_json
      external_source = DataCycleCore::ExternalSystem.find(content['source_key'])
      api_strategy_class = DataCycleCore.allowed_api_strategies.find { |object| object == external_source.config['api_strategy'] }
      api_strategy = api_strategy_class&.constantize&.new(external_source, 'thing', content.values.first['url'].split('/').last, nil)
      @content = api_strategy.create(content.except('source_key'))
      @content = @content.try(:first)

      respond_to do |format|
        format.js do
          if params[:render_html]
            flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language
            render js: "document.location = '#{thing_path(@content)}'"
          end
        end
      end
    end

    def render_embedded_object
      @content = DataCycleCore::Thing.find_by(id: render_embedded_object_params[:id]) || DataCycleCore::Thing.new { |t| t.id = render_embedded_object_params[:id] || SecureRandom.uuid } # new Thing required for bulk_edit
      @key = render_embedded_object_params[:key]
      @definition = render_embedded_object_params[:definition]
      @index = render_embedded_object_params[:index]
      @options = render_embedded_object_params[:options]
      @locale = render_embedded_object_params[:locale]
      @attribute_locale = render_embedded_object_params[:attribute_locale]
      @duplicated_content = render_embedded_object_params[:duplicated_content]
      @hide_embedded = render_embedded_object_params[:hide_embedded]

      if @content&.template
        authorize! :edit, @content
      else
        authorize! :edit, DataCycleCore::Thing
      end

      I18n.with_locale(@locale || I18n.locale) do
        @objects = DataCycleCore::Thing.where(id: render_embedded_object_params[:object_ids]).includes(:translations) if render_embedded_object_params[:object_ids].present?

        respond_to(:js)
        render && return
      end
    end

    def validate
      @object = DataCycleCore::Thing.find_by(id: validation_params[:id]) || DataCycleCore::Thing.find_by(template: true, template_name: validation_params[:template])

      render json: { warning: { content: ['content/template not found'] } } && return if @object.nil?

      authorize! :show, @object

      object_params = content_params(@object.template_name)
      translation_locale = object_params[:translations]&.keys&.first
      translation_values = object_params[:translations]&.dig(translation_locale) || {}
      data_hash = DataCycleCore::DataHashService.flatten_datahash_value((object_params[:datahash] || {}).merge(translation_values), @object.schema)

      I18n.with_locale(translation_locale || validation_params[:locale]) do
        valid = @object.validate(data_hash, nil, validation_params[:strict] == '1', true, current_user)
        render json: valid.to_json
      end
    end

    def load_more_linked_objects
      @content = DataCycleCore::Thing.find(linked_object_params[:content_id]) if linked_object_params[:content_type].present?
      @object = DataCycleCore::Thing.find(linked_object_params[:id])
      authorize! :show, @object

      I18n.with_locale(linked_object_params[:locale] || I18n.locale) do
        @linked_objects = @object.try(linked_object_params[:key])&.where&.not(id: linked_object_params[:load_more_except])&.offset(DataCycleCore.linked_objects_page_size)&.includes(:translations)
        @params = linked_object_params.to_h

        respond_to do |format|
          format.js do
            if linked_object_params[:load_more_action] == 'object_browser'
              render(:load_more_linked_objects_object_browser) && return
            elsif linked_object_params[:load_more_action] == 'embedded_object'
              render(:load_more_linked_objects_embedded_object) && return
            else
              render(:load_more_linked_objects_show) && return
            end
          end
        end
      end
    end

    def load_more_related
      @content = DataCycleCore::Thing.find(params[:id])
      authorize! :show, @content

      @page = (params[:page] || 1).to_i

      @related_objects = @content.related_contents.includes(:translations).order(:template_name, :id).page(@page).per(DataCycleCore.linked_objects_page_size)
      @last_group = params[:last_group]

      respond_to :js
    end

    def upload
      return if asset_params[:file].blank?

      object_type = DataCycleCore.asset_objects.find { |object| object.downcase.include?(asset_params[:file].content_type&.split('/')&.first&.downcase) }

      render(json: { error: I18n.t(:wrong_content_type, scope: [:controllers, :error], locale: DataCycleCore.ui_language) }) && return if object_type.blank?

      authorize! :create, object_type.constantize

      @asset = object_type.constantize.new(asset_params)
      @asset.name = asset_params[:file].original_filename if asset_params[:name].blank?
      @asset.creator_id = current_user.try(:id)
      @asset.save

      external_system = DataCycleCore::ExternalSystem.find_by(name: 'Medienarchiv')
      return if external_system.blank?
      utility_object = DataCycleCore::Export::PushObject.new(external_system: external_system)
      errors = ::Export::MediaArchive::Create.process(utility_object: utility_object, data: @asset)

      render(json: { error: JSON.parse(errors)['errors'] }) && return if errors.present? && JSON.parse(errors).key?('errors')

      render json: @asset
    end

    def remove_locks
      @content = DataCycleCore::Thing.find(params[:id])
      authorize! :remove_lock, @content

      @content.lock&.destroy

      flash[:success] = I18n.t :removed_lock, scope: [:controllers, :success], locale: DataCycleCore.ui_language

      redirect_back(fallback_location: root_path)
    end

    def clear_cache
      authorize! :clear, :cache
      Rails.cache.delete_matched("*#{params[:id]}*")
      redirect_back(fallback_location: root_path)
    end

    def select_search
      authorize! :show, DataCycleCore::Thing
      template_filter = select_search_params[:template_name].present?

      query = DataCycleCore::Filter::Search.new(nil)
      query = query
        .fulltext_search(select_search_params[:q])
        .template_names(select_search_params[:template_name])
        .exclude_ids(select_search_params[:exclude])
      query = query.limit(select_search_params[:max].to_i) if select_search_params[:max].present?

      render plain: query.includes(:translations).map { |content|
        {
          id: content.id,
          class: "#{content.template_name.underscore_blanks} #{content.schema.dig('schema_type').underscore_blanks}",
          name: "#{"<b>#{content.template_name}</b>: " unless template_filter}#{I18n.with_locale(content.first_available_locale) { content.title }} (#{content.translated_locales.join(', ')})",
          title: "#{"#{content.template_name}: " unless template_filter}#{I18n.with_locale(content.first_available_locale) { content.title }} (#{content.translated_locales.join(', ')})"
        }
      }.to_json, content_type: 'application/json'
    end

    private

    def set_watch_list
      watch_list = DataCycleCore::WatchList.find(params[:watch_list_id]) if params[:watch_list_id]
      authorize! :show, watch_list
      @watch_list = watch_list
    end

    def path_params
      params.permit(:path)
    end

    def watch_list_params
      { watch_list_id: @watch_list&.id }
    end

    def select_search_params
      params.permit(:q, :max, :exclude, :template_name)
    end

    def create_locale(params_hash = nil)
      locale_param = (params_hash&.dig(:locale) || params.dig(:thing, :locale))
      I18n.available_locales.include?(locale_param&.to_sym) ? locale_param : I18n.locale.to_s
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

    def asset_proxy_params
      params.permit(:type)
    end

    def linked_object_params
      params.permit(:id, :key, :page, :load_more_action, :locale, :load_more_type, :complete_key, :editable, :content_id, :content_type, definition: {}, load_more_except: [], options: {})
    end

    def life_cycle_params
      params.require(:life_cycle).permit(:name, :id)
    end

    def render_embedded_object_params
      params.permit(:id, :locale, :attribute_locale, :key, :index, :duplicated_content, :hide_embedded, object_ids: [], definition: {}, options: {})
    end

    def validation_params
      params.permit(:id, :template, :strict, :locale)
    end

    def content_params(template_name, params_hash = nil)
      datahash = DataCycleCore::DataHashService.get_object_params(template_name)
      translations = I18n.available_locales.map { |l| [l, datahash] }.to_h

      if params_hash.present?
        params_hash.permit(datahash: datahash, translations: translations)
      else
        params.require(:thing).permit(:version_name, datahash: datahash, translations: translations)
      end
    end

    def new_params
      params.transform_keys(&:underscore).permit(:template, :locale, :key, :search_param, :search_required, :scope, options: [:force_render, :prefix], parent: [:id, :class], content: [:id, :class])
    end

    def destroy_params
      params.permit(:locale)
    end

    def source_params
      return @source_params if defined? @source_params
      @source_params = begin
        if params[:source]
          ActionController::Parameters.new(Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }]).permit(:source_id, :source_locale)
        elsif params[:source_id].present?
          params.permit(:source_id, :source_locale)
        else
          {}
        end
      end
    end
  end
end
