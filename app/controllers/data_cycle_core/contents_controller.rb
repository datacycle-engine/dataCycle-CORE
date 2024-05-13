# frozen_string_literal: true

module DataCycleCore
  class ContentsController < ApplicationController
    include DataCycleCore::FilterConcern
    include DataCycleCore::ExternalConnectionsConcern
    include DataCycleCore::ContentByIdOrTemplate

    before_action :set_watch_list, except: [:asset]
    before_action :set_return_to, only: [:show, :edit]

    DataCycleCore.features.select { |_, v| !v.dig(:only_config) == true }.each_key do |key|
      feature = ModuleService.load_module("Feature::#{key.to_s.classify}", 'Datacycle')
      include feature.controller_module if feature.enabled? && feature.controller_module
    end

    load_and_authorize_resource only: [:index, :show, :destroy]

    def index
      redirect_back(fallback_location: root_path)
    end

    def bulk_create
      new_thing_params = params.dig('thing')

      return if new_thing_params.blank?

      item_count = new_thing_params.keys.size
      index = 0
      content_ids = []

      ActionCable.server.broadcast("bulk_create_#{params[:overlay_id]}_#{current_user.id}", { progress: 0, items: item_count })

      new_thing_params.each_value do |thing_params|
        thing_hash = content_params(params[:template], thing_params)

        I18n.with_locale(create_locale(thing_params)) do
          content = DataCycleCore::DataHashService.create_internal_object(params[:template], thing_hash, current_user)
          content_ids << { id: content.id, field_id: thing_params[:uploader_field_id] } if content.try(:id).present?

          ActionCable.server.broadcast("bulk_create_#{params[:overlay_id]}_#{current_user.id}", { progress: index + 1, items: item_count, error: content.try(:errors).full_messages.join(', '), id: content.id, field_id: thing_params[:uploader_field_id] })
        rescue StandardError => e
          ActionCable.server.broadcast("bulk_create_#{params[:overlay_id]}_#{current_user.id}", { progress: index + 1, items: item_count, error: e.message, id: content.id, field_id: thing_params[:uploader_field_id] })
        ensure
          index += 1
        end
      end

      finished = item_count == content_ids.size

      ActionCable.server.broadcast(
        "bulk_create_#{params[:overlay_id]}_#{current_user.id}",
        {
          created: finished,
          redirect_path: finished ? root_path : nil,
          content_ids:,
          error: finished ? nil : I18n.t('controllers.error.bulk_created', count: item_count - content_ids.size, locale: helpers.active_ui_locale)
        }
      )

      head(:ok)
    rescue StandardError
      finished = item_count == content_ids.size

      ActionCable.server.broadcast(
        "bulk_create_#{params[:overlay_id]}_#{current_user.id}",
        {
          created: finished,
          redirect_path: finished ? root_path : nil,
          content_ids:,
          error: finished ? nil : I18n.t('controllers.error.bulk_created', count: item_count - content_ids.size, locale: helpers.active_ui_locale)
        }
      )
    end

    def show
      @content = DataCycleCore::Thing.find(params[:id])
      redirect_to(thing_path(@content.related_contents.first)) && return if @content.embedded?

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
          format.json do
            if @count_only || params[:mode].present?
              render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/application/count_or_more_results').strip }
            else
              redirect_to send("api_#{DataCycleCore.main_config.dig(:api, :default)}_thing_path", id: @content)
            end
          end
          format.geojson do
            redirect_to send("api_#{DataCycleCore.main_config.dig(:api, :default)}_thing_path", id: @content, format: request.format.symbol)
          end
          format.html { render && return }
        end
      end
    end

    # returns an image for the given content
    # used in asset serializer with image proxy
    # used in api with image proxy
    def asset
      content = DataCycleCore::Thing.find(params[:id])
      raise ActiveRecord::RecordInvalid if ['Audio', 'AudioObject'].include?(content.template_name)

      content = content.try(:image)&.first unless content.respond_to?(:asset)

      attribute = asset_proxy_params.dig(:type) == 'content' && ['Bild', 'ImageVariant', 'ImageObject', 'ImageObjectVariant'].include?(content.template_name) ? :content_url : :thumbnail_url

      raise ActiveRecord::RecordNotFound unless content.respond_to?(attribute)

      if content.try(:asset)&.file&.attached?
        # active storage
        if content.asset.instance_of?(::DataCycleCore::Image)
          rendered_attribute = content.send(attribute)
        else
          content.asset.file.preview(resize_to_limit: [300, 300]).processed unless content.asset.file.preview_image.attached?
          rendered_attribute = content.asset.file.preview_image.url
        end
      else
        # external thing
        rendered_attribute = content.send(attribute)
      end

      raise ActiveRecord::RecordNotFound if rendered_attribute.blank?

      uri = Addressable::URI.parse(rendered_attribute)
      # used for local development and docker env.
      redirect_to(uri.to_s, allow_other_host: true)
    end

    def new
      @resolved_params = resolve_params(new_params).symbolize_keys
      @template = DataCycleCore::Thing.new(template_name: @resolved_params[:template])
      raise ActiveRecord::RecordNotFound if @template.template_missing?

      render json: {
        html: render_to_string(formats: [:html], layout: false).strip,
        enable: !@resolved_params[:search_required] || @resolved_params[:search_param].present? || can?(:create_without_search, @template)
      }
    end

    def edit
      @content ||= DataCycleCore::Thing.find(params[:id])
      @hide_embedded = params[:hide_embedded].present?

      redirect_to(edit_thing_path(@content.related_contents.first)) && return if @content.embedded?

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

    def create
      template = DataCycleCore::Thing.new(template_name: params[:template])
      authorize!(__method__, template, resolve_params(params, false).dig(:scope))

      @object_browser_parent = content_by_id_or_template

      I18n.with_locale(create_locale) do
        object_params = content_params(params[:template])

        if source_params.present?
          source = DataCycleCore::Thing.find_by(id: source_params[:source_id])
        else
          source = DataCycleCore::Thing.find_by(id: parent_params[:parent_id])
        end

        @content = DataCycleCore::DataHashService.create_internal_object(params[:template], object_params, current_user, parent_params[:parent_id], source)
        if @content.try(:errors).present?
          flash[:error] = @content.errors.full_messages # rubocop:disable Rails/ActionControllerFlashBeforeRender
        elsif @content.present?
          flash[:success] = I18n.t('controllers.success.created', data: @content.template_name, locale: helpers.active_ui_locale)
        end

        respond_to do |format|
          format.html do
            if @content.valid?
              redirect_to edit_thing_path(@content, source_params.merge(watch_list_params))
            else
              redirect_back(fallback_location: root_path)
            end
          end

          format.json do
            render json: {
              html: @content.present? ? render_to_string(formats: [:html], layout: false, locals: { :@objects => Array.wrap(@content) }).strip : nil,
              detail_html: @content.present? ? render_to_string('data_cycle_core/object_browser/details', formats: [:html], layout: false, locals: { :@object => @content }).strip : nil,
              ids: Array.wrap(@content&.id),
              **flash.discard.to_h
            }
          end
        end
      end
    end

    def edit_by_external_key
      raise ActionController::BadRequest if params[:external_key].blank? || params[:external_system_id].blank?

      @content = DataCycleCore::Thing.by_external_key(params[:external_system_id], params[:external_key]).first

      raise ActiveRecord::RecordNotFound if @content.nil?

      redirect_to(edit_thing_path(@content.related_contents.first)) && return if @content.embedded?

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
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params, @content.schema)
        @content.finalize = params[:finalize] if DataCycleCore::Feature::Releasable.enabled?
        merge_duplicate = params[:duplicate_id].present? && self.class.method_defined?(:merge_and_remove_duplicate)

        version_name_for_merge(datahash) if merge_duplicate

        unless @content.set_data_hash_with_translations(data_hash: datahash, current_user:, force_update: merge_duplicate)
          flash[:error] = @content.i18n_errors.map { |k, v| v.full_messages.map { |m| "#{k}: #{m}" } }.flatten
          redirect_back(fallback_location: root_path) && return
        end

        if @content.warnings.present?
          flash[:info] = @content.warnings.messages
        else
          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @content.template_name, locale: helpers.active_ui_locale
        end

        merge_and_remove_duplicate if merge_duplicate

        if params[:new_locale].present?
          redirect_to(edit_thing_path(@content, watch_list_params.merge(locale: params[:new_locale])))
        elsif !params[:save_and_close] && !params[:finalize] && !merge_duplicate
          redirect_back(fallback_location: root_path)
        else
          redirect_to(thing_path(@content, watch_list_params.merge(locale: I18n.locale)))
        end
      end
    end

    def destroy
      @content = DataCycleCore::Thing.find(params[:id])

      I18n.with_locale(@content.first_available_locale(destroy_params[:locale])) do
        destroy_content_params = { current_user: }
        if @content.external_source_id.present?
          destroy_content_params[:save_history] = true
          destroy_content_params[:destroy_linked] = true
        end

        destroy_content_params[:destroy_locale] = destroy_params[:locale].present?

        @content.destroy_content(**destroy_content_params)

        flash[:success] = @content.destroyed? ? I18n.t(:destroyed, scope: [:controllers, :success], data: @content.template_name, locale: helpers.active_ui_locale) : I18n.t(:destroyed_translation, scope: [:controllers, :success], data: @content.template_name, language: I18n.locale, locale: helpers.active_ui_locale)

        redirect_to(thing_path(@content, watch_list_params)) && return unless @content.destroyed?
        redirect_to(thing_path(@content.parent, watch_list_params)) && return if @content.try(:parent).present?
        redirect_to(watch_list_path(watch_list_params[:watch_list_id])) && return if watch_list_params[:watch_list_id].present?
        redirect_to root_path
      end
    end

    def compare
      @content = DataCycleCore::Thing.includes(:classifications).find(params[:id])
      authorize! :show, @content

      redirect_back(fallback_location: root_path, alert: (I18n.t :no_source, scope: [:controllers, :error], locale: helpers.active_ui_locale)) && return if source_params.blank?

      @diff_source = DataCycleCore::Thing.find(source_params[:source_id])

      redirect_back(fallback_location: root_path) && return if @diff_source.nil? || @content.nil?

      I18n.with_locale(@source_locale) do
        @target_locale = @content.first_available_locale
        I18n.with_locale(@target_locale) { @data_schema = @content.get_data_hash }
        @diff_schema = @diff_source.diff(@data_schema)

        if @source_locale.to_s != @target_locale.to_s
          @content.translatable_property_names.each do |key|
            @diff_schema[key] = ['0', nil]
          end
        end

        render
      rescue StandardError => e
        redirect_back(fallback_location: root_path, alert: helpers.tag.span(I18n.t('controllers.error.definition_mismatch', locale: helpers.active_ui_locale), title: "#{e.message.truncate(250)}\n\n#{e.backtrace.first(10).join("\n")}")) && return
      end
    end

    def history
      @content = DataCycleCore::Thing.find_by(id: params[:id]) || DataCycleCore::Thing::History.find_by(id: params[:id])
      @diff_source = DataCycleCore::Thing.find_by(id: params[:history_id]) || DataCycleCore::Thing::History.find_by(id: params[:history_id])

      raise ActiveRecord::RecordNotFound if @content.nil? || @diff_source.nil?

      authorize! :history, @content

      @source_locale = @diff_source.first_available_locale(@diff_source.last_updated_locale)

      I18n.with_locale(@source_locale) do
        @target_locale = @content.first_available_locale(@content.last_updated_locale)
        I18n.with_locale(@target_locale) { @data_schema = @content.get_data_hash }
        @diff_schema = @diff_source.diff(@data_schema) || {}

        if @source_locale.to_s != @target_locale.to_s
          @content.translatable_property_names.each do |key|
            if key.in?(@content.embedded_property_names)
              if @diff_schema.dig(key, 0, 0).present?
                @diff_schema[key][0][0] = '0'
              else
                @diff_schema[key] = [['0', nil]]
              end
            else
              @diff_schema[key] = ['0', nil]
            end
          end
        end

        render
      rescue StandardError => e
        redirect_back(fallback_location: root_path, alert: helpers.tag.span(I18n.t('controllers.error.definition_mismatch', locale: helpers.active_ui_locale), title: "#{e.message.truncate(100)}\n\n#{e.backtrace.first(5).join("\n")}"), allow_other_host: false) && return
      end
    end

    def restore_history_version
      @content = DataCycleCore::Thing.find(params[:id])
      @history = @content.histories.find(params[:history_id]) if params[:history_id].present?

      redirect_back(fallback_location: root_path, allow_other_host: false) && return if @history.nil? || @content.nil?

      I18n.with_locale(@history.first_available_locale) do
        history_hash = @history.get_data_hash
        history_date = @history.try(:updated_at)&.in_time_zone
        history_date_string = I18n.l(history_date, locale: helpers.active_ui_locale, format: :history) if history_date.present?

        if @content.set_data_hash(data_hash: history_hash, version_name: I18n.t(:restored_version_name, scope: [:history, :restore, :version], locale: helpers.active_ui_locale, date: history_date_string), partial_update: false)
          flash[:success] = I18n.t(:restored, scope: [:history, :restore, :version], locale: helpers.active_ui_locale, date: history_date_string)
        else
          flash[:error] = @content.i18n_errors.map { |k, v| v.full_messages.map { |m| "#{k}: #{m}" } }.flatten
        end

        redirect_to thing_path(@content, watch_list_params)
      rescue StandardError
        redirect_back(fallback_location: root_path, alert: (I18n.t :definition_mismatch, scope: [:controllers, :error], locale: helpers.active_ui_locale))
      end
    end

    def import
      content = params[:data].as_json
      external_source = DataCycleCore::ExternalSystem.find(content['source_key'])
      api_strategy_class = DataCycleCore.allowed_api_strategies.find { |object| object == external_source.config['api_strategy'] }
      api_strategy = api_strategy_class&.constantize&.new(external_source, 'thing', content.values.first['url'].split('/').last, nil)
      @content = api_strategy.create(content.except('source_key'))
      @content = @content.try(:first)

      flash.now[:success] = I18n.t('controllers.success.created', data: @content.template_name, locale: helpers.active_ui_locale)

      if params[:render_html]
        render js: "document.location = '#{thing_path(@content)}'"
      else
        render json: {
          html: render_to_string(formats: [:html], layout: false, action: 'create', locals: { :@objects => Array.wrap(@content) }).strip,
          detail_html: render_to_string('data_cycle_core/object_browser/details', formats: [:html], layout: false, locals: { :@object => @content }).strip,
          ids: Array.wrap(@content&.id),
          **flash.discard.to_h
        }
      end
    end

    def render_embedded_object
      @content = DataCycleCore::Thing.find_by(id: render_embedded_object_params[:id]) || content_by_id_or_template
      @key = render_embedded_object_params[:key]
      @definition = render_embedded_object_params[:definition]
      @index = render_embedded_object_params[:index]
      @options = render_embedded_object_params[:options]
      @locale = render_embedded_object_params[:locale]
      @attribute_locale = render_embedded_object_params[:attribute_locale]
      @duplicated_content = render_embedded_object_params[:duplicated_content]
      @hide_embedded = render_embedded_object_params[:hide_embedded]
      @translate = render_embedded_object_params[:translate]
      @embedded_template = render_embedded_object_params[:embedded_template]

      if @content&.persisted?
        authorize! :edit, @content
      else
        authorize! :edit, DataCycleCore::Thing
      end

      I18n.with_locale(@locale || I18n.locale) do
        @objects = DataCycleCore::Thing.includes(:translations).by_ordered_values(render_embedded_object_params[:object_ids]) if render_embedded_object_params[:object_ids].present?

        render(json: { html: render_to_string(formats: [:html], layout: false).strip }) && return
      end
    end

    def validate
      @object = DataCycleCore::Thing.find_by(id: validation_params[:id]) || DataCycleCore::Thing.new(template_name: validation_params[:template])

      render(json: { warning: { content: ['content/template not found'] } }) && return if @object.nil?

      authorize! :show, @object

      object_params = content_params(@object.template_name)
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params, @object.schema)
      locale, values = datahash[:translations]&.first
      datahash = (datahash[:datahash] || {}).merge(values || {})

      I18n.with_locale(locale || validation_params[:locale]) do
        @object.validate(data_hash: datahash, strict: validation_params[:strict] == '1', add_defaults: true, current_user:)

        duplicate_search_data = DataCycleCore::StoredFilter.validate_by_duplicate_search(@object, datahash, validation_params[:duplicate_search], current_user, helpers.active_ui_locale) if validation_params[:duplicate_search]

        render json: @object.validation_messages_as_json.merge(duplicate_search_data.to_h).to_json
      end
    end

    def load_more_linked_objects
      @content = DataCycleCore::Thing.find(linked_object_params[:content_id]) if linked_object_params[:content_type].present?
      @object = DataCycleCore::Thing.find(linked_object_params[:id])
      authorize! :show, @object

      @locale = linked_object_params[:locale]

      I18n.with_locale(@locale) do
        @linked_objects = @object.try(linked_object_params[:key])&.where&.not(id: linked_object_params[:load_more_except])&.offset(DataCycleCore.linked_objects_page_size)&.includes(:translations)
        @params = linked_object_params.to_h

        render_action = case linked_object_params[:load_more_action]
                        when 'object_browser' then :load_more_linked_objects_object_browser
                        when 'embedded_object' then :load_more_linked_objects_embedded_object
                        else :load_more_linked_objects_show
                        end

        respond_to do |format|
          format.json do
            render json: { html: render_to_string(formats: [:html], layout: false, action: render_action).strip, ids: @linked_objects.pluck(:id) }
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

      I18n.with_locale(params[:locale]) do
        respond_to do |format|
          format.js do
            render
          end
        end
      end
    end

    def load_more_duplicates
      @content = DataCycleCore::Thing.find(load_more_duplicates_params[:id])
      authorize! :show, @content

      @items = @content.duplicate_candidates&.offset(DataCycleCore.linked_objects_page_size)
      @prefix = load_more_duplicates_params[:prefix]

      render 'data_cycle_core/duplicate_candidates/load_more_duplicates'
    end

    def remove_locks
      @content = DataCycleCore::Thing.find(params[:id])
      authorize! :remove_lock, @content

      @content.lock&.destroy

      flash[:success] = I18n.t :removed_lock, scope: [:controllers, :success], locale: helpers.active_ui_locale

      redirect_back(fallback_location: root_path)
    end

    def clear_cache
      authorize! :clear, :cache

      @content = DataCycleCore::Thing.find(params[:id])
      @content.invalidate_self

      redirect_back(fallback_location: root_path)
    end

    def destroy_auto_translate
      authorize! :destroy, :auto_translate
      thing = DataCycleCore::Thing.find(params[:id])
      thing.destroy_auto_translations
      redirect_back(fallback_location: root_path)
    end

    def select_search
      authorize! :show, DataCycleCore::Thing

      filter = DataCycleCore::StoredFilter.new.parameters_from_hash(select_search_params[:stored_filter])
      query = filter.apply
      query = query
        .fulltext_search(select_search_params[:q])
        .template_names(select_search_params[:template_name])
        .exclude_ids(select_search_params[:exclude])
      query = query.limit(select_search_params[:max].to_i) if select_search_params[:max].present?
      query = query.sort_fulltext_search('DESC', select_search_params[:q])

      render plain: query.includes(:translations).map { |t| t.to_select_option(helpers.active_ui_locale) }.to_json,
             content_type: 'application/json'
    end

    def attribute_value
      content = DataCycleCore::Thing.find(attribute_value_params[:id])

      values = {}

      attribute_value_params[:keys].each do |key|
        key_path = key.attribute_path_from_key
        key_locale = key.scan(/\[translations\]\[([^\]]*)\]/).flatten.first

        next if key_path.blank?

        I18n.with_locale(key_locale || attribute_value_params[:locale]) do
          value = (value || content).try(key_path.shift) while key_path.present?
          values[key] = value
          values[key] = RGeo::GeoJSON.encode(values[key]) if values[key].presence.try(:geometry_type)
          values[key] = values[key].id if values[key].is_a?(ActiveRecord::Base)
          values[key] = values[key].pluck(:id) if values[key].is_a?(ActiveRecord::Relation)
        end
      end

      render json: values.reject { |_k, v| DataCycleCore::DataHashService.blank?(v) }.to_json
    end

    def geojson_for_map_editor
      authorize! :index, DataCycleCore::Thing

      render(plain: { type: 'FeatureCollection', features: [] }.to_json, content_type: 'application/vnd.geo+json') && return if map_editor_params.blank?

      template_name = map_editor_params[:template_name]
      filter_hash = map_editor_params[:stored_filter]
      stored_filter = DataCycleCore::StoredFilter.new
        .parameters_from_hash(filter_hash)
        .apply_user_filter(current_user, { scope: 'object_browser', template_name: filter_hash.blank? ? template_name : nil })

      if map_editor_params[:filter].present?
        stored_filter.parameters.concat Array.wrap({
          't' => 'classification_alias_ids',
          'm' => 'i',
          'v' => map_editor_params[:filter]
        })
      end

      query = stored_filter.apply
      query = query.where(template_name: template_name.to_s) if template_name && filter_hash.blank?
      query = query.where(id: map_editor_params[:ids]) if map_editor_params[:ids].present?
      query = query.with_geometry

      render plain: query.query.to_geojson, content_type: 'application/geo+json'
    end

    def attribute_default_value
      authorize! :show, DataCycleCore::Thing
      template = DataCycleCore::Thing.new(template_name: default_value_params[:template_name])
      raise ActiveRecord::RecordNotFound if template.template_missing?

      I18n.with_locale(default_value_params[:locale] || DataCycleCore.ui_locales.first) do
        render(
          json: template.default_values_as_form_data(
            keys: default_value_params[:keys],
            data_hash: default_value_params[:data_hash] || {},
            user: current_user
          )
        ) && return
      end
    end

    def content_score
      authorize! :show, DataCycleCore::Thing

      raise ActiveRecord::RecordNotFound unless DataCycleCore::Feature::ContentScore.enabled?
      content = DataCycleCore::Thing.find_by(id: content_score_params[:id]) || DataCycleCore::Thing.new(template_name: content_score_params[:template_name])

      raise ActiveRecord::RecordNotFound if content.nil?

      object_params = content_params(content.template_name, params[:thing])
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params, content.schema)

      _locale, values = datahash[:translations]&.first
      datahash = (datahash[:datahash] || {}).merge(values || {})

      I18n.with_locale(content_score_params[:locale]) do
        render(
          json: {
            value: content.calculate_content_score(
              content_score_params[:attribute_key],
              datahash
            )
          }
        ) && return
      end
    end

    def create_external_connection
      @content = DataCycleCore::Thing.find(params[:id])

      authorize! :create_external_connection, @content

      begin
        external_system_sync = @content.external_system_syncs.create(external_connection_params.merge(sync_type: 'duplicate'))
        @content.invalidate_self

        if external_system_sync.valid?
          flash[:success] = I18n.t('external_connections.new_form.created', locale: helpers.active_ui_locale)
        else
          flash[:error] = I18n.with_locale(helpers.active_ui_locale) { external_system_sync.errors.full_messages }
        end
      rescue ActiveRecord::RecordNotUnique
        flash[:error] = I18n.t('external_connections.new_form.duplicate_error', locale: helpers.active_ui_locale)
      end

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path) }
        format.json { render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/contents/external_connections', locals: { content: @content }).strip, **flash.discard.to_h } }
      end
    end

    def elevation_profile
      content = DataCycleCore::Thing.find(elevation_profile_params[:id])
      @renderer = DataCycleCore::ApiRenderer::ElevationProfileRenderer.new(content:, locale: helpers.active_ui_locale)

      begin
        render json: @renderer.render
      rescue DataCycleCore::ApiRenderer::Error::RendererError => e
        render json: { error: e.message }, status: e.status_code
      end
    end

    private

    def external_connection_params
      params.require(:external_system_sync).permit(:external_system_id, :external_key)
    end

    def content_score_params
      params.permit(:id, :template_name, :attribute_key, :locale)
    end

    def default_value_params
      params.permit(:template_name, :locale, keys: [], data_hash: {})
    end

    def elevation_profile_params
      params.permit(:id)
    end

    def set_watch_list
      return if params[:watch_list_id].blank?

      watch_list = DataCycleCore::WatchList.find(params[:watch_list_id])
      authorize! :show, watch_list
      @watch_list = watch_list
    end

    def set_return_to
      return if session[:return_to].present?

      referer_url = Addressable::URI.parse(request.referer.to_s)

      return if referer_url.host != request.host

      allowed_paths = [root_path]
      allowed_paths = [watch_list_path(@watch_list.id)] if @watch_list.present?

      return if allowed_paths.exclude?(referer_url.path)

      session[:return_to] = request.referer
    end

    def attribute_value_params
      params.permit(:id, :locale, keys: [])
    end

    def path_params
      params.permit(:path)
    end

    def watch_list_params
      { watch_list_id: @watch_list&.id }
    end

    def select_search_params
      return @select_search_params if defined? @select_search_params

      @select_search_params = DataCycleCore::NormalizeService.normalize_parameters(params.permit(:q, :max, :exclude, :template_name, stored_filter: {}))
    end

    def create_locale(params_hash = nil)
      locale_param = params_hash&.dig(:locale) || params.dig(:thing, :locale)
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
      params.transform_keys(&:underscore).permit(:id, :key, :page, :load_more_action, :locale, :load_more_type, :complete_key, :editable, :content_id, :content_type, :hide_embedded, definition: {}, load_more_except: [], options: {})
    end

    def life_cycle_params
      params.require(:life_cycle).permit(:name, :id)
    end

    def render_embedded_object_params
      params.permit(:id, :locale, :attribute_locale, :key, :index, :duplicated_content, :hide_embedded, :translate, :embedded_template, object_ids: [], definition: {}, options: {})
    end

    def validation_params
      params.permit(:id, :template, :strict, :locale, :duplicate_search)
    end

    def content_params(template_name, params_hash = nil)
      params_hash = params.fetch(:thing) { {} } if params_hash.blank?
      params_hash.permit(:version_name, DataCycleCore::DataHashService.get_object_params(template_name, params_hash))
    end

    def new_params
      params.transform_keys(&:underscore).permit(:template, :locale, :key, :search_param, :search_required, :scope, options: [:force_render, :prefix], parent: [:id, :class], content: [:id, :class])
    end

    def destroy_params
      params.permit(:locale)
    end

    def source_params
      return @source_params if defined? @source_params
      @source_params = if params[:source]
                         ActionController::Parameters.new(params[:source].split(',').to_h { |x| x.strip.split('=>') }).permit(:source_id, :source_locale)
                       elsif params[:source_id].present?
                         params.permit(:source_id, :source_locale)
                       else
                         {}
                       end
    end

    def load_more_duplicates_params
      params.permit(:id, :prefix)
    end

    def map_editor_params
      return @map_editor_params if defined? @map_editor_params

      @map_editor_params = DataCycleCore::NormalizeService.normalize_parameters(params.permit(:template_name, ids: [], filter: []).merge(params.slice(:stored_filter).permit!))
    end
  end
end
