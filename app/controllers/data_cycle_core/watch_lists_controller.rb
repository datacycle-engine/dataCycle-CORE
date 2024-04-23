# frozen_string_literal: true

module DataCycleCore
  class WatchListsController < ApplicationController
    include DataCycleCore::FilterConcern
    include DataCycleCore::Feature::ControllerFunctions::ContentLock if DataCycleCore::Feature::ContentLock.enabled?
    include DataCycleCore::BulkUpdateTypes

    load_and_authorize_resource only: [:index, :show, :new, :create, :edit, :update, :destroy, :remove_item, :add_item] # from cancancan (authorize)
    prepend_before_action :load_previous_page, only: :show, if: :load_previous_page?

    def index
      @contents = current_user.watch_lists.page(params[:page])
    end

    def show
      @watch_list = DataCycleCore::WatchList.find_by(id: params[:id])

      redirect_to root if @watch_list.nil?

      @language ||= params.fetch(:language) { ['all'] }
      pre_filters
      @pre_filters.push({ 't' => 'watch_list_id', 'v' => @watch_list.id })

      set_instance_variables_by_view_mode(query: @query, user_filter: { scope: 'watch_list' }, watch_list: @watch_list)

      respond_to do |format|
        format.html
        format.json do
          if @count_only || params[:mode].present?
            render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/application/count_or_more_results').strip }
          else
            redirect_to send("api_#{DataCycleCore.main_config.dig(:api, :default)}_collection_path", id: @watch_list)
          end
        end
        format.geojson { redirect_to send("api_#{DataCycleCore.main_config.dig(:api, :default)}_collection_path", id: @watch_list, format: request.format.symbol) }
      end
    end

    def new
      @watch_list = DataCycleCore::WatchList.new
    end

    def edit
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      return if params[:data_id].blank?
      add_remove_data params
      redirect_back(fallback_location: root_path)
    end

    def create
      @watch_list = current_user.watch_lists.build(watch_list_params)
      @new_form_id = create_form_params[:new_form_id]

      respond_to do |format|
        if !@watch_list.nil? && @watch_list.save
          format.js
          format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :created, scope: [:controllers, :success], data: DataCycleCore::WatchList.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale)) }
        else
          format.html { redirect_back(fallback_location: root_path) }
        end
      end
    end

    def update
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      @watch_list.update(watch_list_params)

      if @watch_list.save
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: DataCycleCore::WatchList.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale

        if Rails.env.development?
          redirect_to edit_watch_list_path(@watch_list)
        else
          redirect_to watch_list_path(@watch_list)
        end

      else
        render 'edit'
      end
    end

    def destroy
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      @watch_list.destroy

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: DataCycleCore::WatchList.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale
      redirect_to root_path
    end

    def remove_item
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      @content_object = DataCycleCore::Thing.find(params[:hashable_id])
      @content_object.watch_lists.destroy(@watch_list) unless @content_object.nil? || @watch_list.nil?

      @watch_list.notify_subscribers(current_user, [@content_object.id], 'remove')

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: I18n.t('controllers.success.removed_from', data: @watch_list.name, type: DataCycleCore::WatchList.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale)) }
        format.js
      end
    end

    def add_item
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      @content_object = DataCycleCore::Thing.find(params[:hashable_id])
      @content_object.watch_lists << @watch_list unless @content_object.nil? || @watch_list.nil? || @watch_list.id.in?(@content_object.watch_list_ids)

      @watch_list.notify_subscribers(current_user, [@content_object.id], 'add')

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: I18n.t('controllers.success.added_to', data: @watch_list.name, type: DataCycleCore::WatchList.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale)) }
        format.js
      end
    end

    def add_related_items
      @watch_list = DataCycleCore::WatchList.find_by(id: params[:watch_list_id])
      @watch_list = current_user.watch_lists.create(full_path: params[:watch_list_id]) if @watch_list.nil?

      authorize!(:add_item, @watch_list)

      content = DataCycleCore::Thing.find(params[:content_id])
      related_objects = content&.related_contents&.joins(:content_content_a)&.where(template_name: params[:template_name], content_contents: { content_b_id: params[:content_id], relation_a: params[:relation_a] })

      inserted_ids = @watch_list.add_things_from_query(related_objects)

      @watch_list.notify_subscribers(current_user, inserted_ids, 'add')

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: I18n.t('controllers.success.added_to', data: @watch_list.name, type: DataCycleCore::WatchList.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale)) }
        format.js
      end
    end

    def bulk_edit
      @watch_list ||= DataCycleCore::WatchList.find(params[:id])

      authorize!(:bulk_edit, @watch_list)

      I18n.with_locale(params[:locale]) do
        @locale = I18n.locale

        redirect_to(watch_list_path(@watch_list), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: helpers.active_ui_locale)) && return unless @watch_list.things.all? { |t| can?(:edit, t) }

        render && return
      end
    end

    def bulk_update
      @watch_list ||= DataCycleCore::WatchList.find(params[:id])

      authorize!(:bulk_edit, @watch_list)

      bulk_edit_types = bulk_update_type_params
      bulk_edit_allowed_keys = Array.wrap(bulk_edit_types.dig(:datahash)&.keys).concat(Array.wrap(bulk_edit_types.dig(:translations)&.values&.map(&:keys)&.flatten))

      @object = DataCycleCore::Thing.new(thing_template: content_template, id: SecureRandom.uuid)
      @object.schema['properties'].slice!(*bulk_edit_allowed_keys)

      object_params = content_params(@object.schema)

      if object_params.dig(:datahash).blank? && object_params.dig(:translations).blank?
        flash.now[:error] = I18n.t(:no_selected_attributes, scope: [:controllers, :error], locale: helpers.active_ui_locale)
        ActionCable.server.broadcast("bulk_update_#{@watch_list.id}_#{current_user.id}", { redirect_path: watch_list_path(@watch_list, flash: flash.to_hash) })
        return head(:ok)
      end

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params, @object.schema)

      I18n.with_locale(params[:locale]) do
        unless can?(:bulk_edit, @watch_list) && @watch_list.things.all? { |t| can?(:update, t) }
          flash.now[:error] = I18n.t :no_permission, scope: [:controllers, :error], locale: helpers.active_ui_locale
          ActionCable.server.broadcast("bulk_update_#{@watch_list.id}_#{current_user.id}", { redirect_path: watch_list_path(@watch_list, flash: flash.to_hash) })
          return head(:ok)
        end

        update_items = @watch_list.things.includes(:translations)
        item_count = update_items.size
        errors = []
        skip_update_count = {}

        ActionCable.server.broadcast("bulk_update_#{@watch_list.id}_#{current_user.id}", { progress: 0, items: item_count })

        update_items.find_each.with_index do |content, index|
          specific_datahash = datahash.dc_deep_dup.with_indifferent_access
          allowed_translations = content.available_locales.map(&:to_s)
          translations = Array.wrap(datahash.dig(:translations)&.keys)
          translations.difference(allowed_translations).each do |l|
            skip_update_count[l] ||= 0
            skip_update_count[l] += 1
          end

          specific_datahash[:translations]&.slice!(*allowed_translations)

          if specific_datahash[:translations].present? || specific_datahash[:datahash].present?
            I18n.with_locale(content.first_available_locale(specific_datahash[:translations]&.keys&.first || params[:locale])) do
              valid = content.set_data_hash_with_translations(
                data_hash: transform_exisiting_values(bulk_edit_types, @object.schema, specific_datahash, content),
                current_user:
              )
              errors.concat(Array.wrap(content.errors.full_messages)) unless valid
            end
          end

          ActionCable.server.broadcast("bulk_update_#{@watch_list.id}_#{current_user.id}", { progress: index + 1, items: item_count })
        end

        if errors.present?
          error_string = errors.first(5).join('<br>')
          error_string += "<br>+ #{I18n.t('common.more_errors', count: errors.size - 5, locale: helpers.active_ui_locale)}" if errors.size > 5
          flash.now[:error] = error_string
        else
          flash.now[:success] = I18n.t :bulk_updated, scope: [:controllers, :success], count: item_count, locale: helpers.active_ui_locale

          if skip_update_count.any? { |_k, v| v.positive? }
            flash.now[:success] += I18n.t :bulk_updated_skipped_html,
                                          scope: [:controllers, :info],
                                          counts: skip_update_count
                                            .select { |_k, v| v.positive? }
                                            .map { |k, v| "#{k}: <b>#{v}</b>" }
                                            .join(', '),
                                          locale: helpers.active_ui_locale
          end
        end

        @watch_list.watch_list_data_hashes.delete_all if @watch_list.my_selection

        ActionCable.server.broadcast("bulk_update_#{@watch_list.id}_#{current_user.id}", { redirect_path: watch_list_path(@watch_list, flash: flash.to_hash) })

        head(:ok)
      end
    rescue StandardError
      flash.now[:error] = I18n.t :bulk_update_error, scope: [:controllers, :error], locale: helpers.active_ui_locale
      ActionCable.server.broadcast("bulk_update_#{@watch_list.id}_#{current_user.id}", { redirect_path: bulk_edit_watch_list_path(@watch_list, flash: flash.to_hash) })
    end

    def bulk_delete
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      authorize!(:bulk_delete, @watch_list)

      unless can?(:bulk_delete, @watch_list)
        flash.now[:error] = I18n.t :no_permission, scope: [:controllers, :error], locale: helpers.active_ui_locale
        ActionCable.server.broadcast("bulk_delete_#{@watch_list.id}", { redirect_path: watch_list_path(@watch_list, flash: flash.to_hash) })
        return head(:ok)
      end

      delete_items = @watch_list.things
      delete_count = delete_items.size
      cant_delete_count = 0

      ActionCable.server.broadcast("bulk_delete_#{@watch_list.id}", { progress: 0, items: delete_count })
      delete_items.find_each.with_index do |content, index|
        if can?(:destroy, content)
          content.destroy_content
        else
          cant_delete_count += 1
        end

        ActionCable.server.broadcast("bulk_delete_#{@watch_list.id}", { progress: index + 1, items: delete_count })
      end

      flash.now[:success] = I18n.t(:bulk_deleted, scope: [:controllers, :success], count: delete_count, locale: helpers.active_ui_locale)
      flash.now[:success] += I18n.t(:bulk_deleted_not_allowed_html, scope: [:controllers, :info], locale: helpers.active_ui_locale, count: cant_delete_count) if cant_delete_count.positive?

      ActionCable.server.broadcast("bulk_delete_#{@watch_list.id}", { redirect_path: watch_list_path(@watch_list, flash: flash.to_hash) })
      head(:ok)
    end

    def validate
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      if params[:watch_list].present?
        @watch_list.attributes = watch_list_params

        render json: {
          valid: @watch_list.validate,
          errors: @watch_list.errors.messages
        }
      else
        render(json: { warning: { content: ['content not found'] } }) && return if params[:thing].blank?

        @object = DataCycleCore::Thing.new(thing_template: content_template, id: SecureRandom.uuid)

        object_params = content_params(@object.schema)
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params, @object.schema)
        locale, values = datahash[:translations]&.first
        datahash = (datahash[:datahash] || {}).merge(values || {})

        I18n.with_locale(locale) do
          @object.validate(data_hash: datahash, current_user:)

          render json: @object.validation_messages_as_json.to_json
        end
      end
    end

    def clear
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      authorize! :remove_item, @watch_list

      deleted_ids = @watch_list.delete_all_watch_list_data_hashes

      @watch_list.notify_subscribers(current_user, deleted_ids, 'remove')

      redirect_back(
        fallback_location: root_path,
        notice: (
          I18n.t :cleared_collection,
                 scope: [:controllers, :success],
                 data: @watch_list.name,
                 locale: helpers.active_ui_locale
        )
      )
    end

    def search
      authorize! :show, DataCycleCore::WatchList

      watch_lists = DataCycleCore::WatchList
        .accessible_by(current_ability)
        .conditional_my_selection
        .order(updated_at: :desc)
        .limit(20)

      watch_lists = watch_lists.where(DataCycleCore::WatchList.arel_table[:full_path].matches("%#{search_params[:q]}%")) if search_params[:q].present?

      render plain: watch_lists.map(&:to_select_option).to_json, content_type: 'application/json'
    end

    def update_order
      @watch_list = DataCycleCore::WatchList.find(update_order_params[:id])

      authorize! :manual_order, @watch_list

      @watch_list.update_order_by_array(update_order_params[:order])

      flash.now[:success] = I18n.t('collection.manual_order.success', locale: helpers.active_ui_locale)

      render json: flash.discard.to_h
    end

    private

    def update_order_params
      params.permit(:id, order: [])
    end

    def watch_list_params
      params.require(:watch_list).permit(:full_path, :description, :user_id, :manual_order, :api, :linked_stored_filter_id, shared_user_group_ids: [], shared_user_ids: [], shared_role_ids: [], classification_tree_labels: [])
      .tap do |p|
        p[:description] = DataCycleCore::MasterData::DataConverter.string_to_string(p[:description]) if p.key?(:description)
      end
    end

    def create_form_params
      params.permit(:new_form_id)
    end

    def search_params
      params.permit(:q)
    end

    def hashable_params
      params.permit(:hashable_id, :hashable_type, serialize_format: [])
    end

    def bulk_update_type_params
      return {} if params[:bulk_update].blank?

      params.require(:bulk_update).permit(datahash: {}, translations: {})
    end

    def content_template
      resolve_params(JSON.parse(params.permit(:content_template)[:content_template]))&.dig(:thing_template)
    rescue StandardError
      nil
    end

    def content_params(schema_hash)
      allowed_content_params = DataCycleCore::DataHashService.get_params_from_hash(schema_hash)

      return {} if params[:thing].blank?

      params.require(:thing).permit(allowed_content_params)
    end
  end
end
