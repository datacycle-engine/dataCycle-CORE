# frozen_string_literal: true

module DataCycleCore
  class WatchListsController < ApplicationController
    include DataCycleCore::Filter
    include DataCycleCore::DownloadHandler if DataCycleCore::Feature::Download.enabled?
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource only: [:index, :show, :new, :create, :edit, :update, :destroy, :remove_item, :add_item, :download] # from cancancan (authorize)

    def index
      @contents = current_user.watch_lists.page(params[:page])
    end

    def show
      @watch_list = DataCycleCore::WatchList.find_by(id: params[:id])

      redirect_to root if @watch_list.nil?

      @language ||= params.fetch(:language) { ['all'] }
      filters
      @filters.push(
        {
          't' => 'watch_list_id',
          'v' => @watch_list.id
        }
      )

      @contents = get_filtered_results.distinct_by_content_id(@order_string).content_includes.page(params[:page])
      @total = @contents.total_count

      respond_to do |format|
        format.html
        format.json { redirect_to api_v2_collection_path(id: @watch_list) }
      end
    end

    def new
      @watch_list = DataCycleCore::WatchList.new
    end

    def create
      @watch_list = current_user.watch_lists.build(watch_list_params)

      respond_to do |format|
        if !@watch_list.nil? && @watch_list.save
          format.js
          format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :created, scope: [:controllers, :success], data: DataCycleCore::WatchList.model_name.human(count: 1, locale: DataCycleCore.ui_language), locale: DataCycleCore.ui_language)) }
        else
          format.html { redirect_back(fallback_location: root_path) }
        end
      end
    end

    def edit
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      return if params[:data_id].blank?
      add_remove_data params
      redirect_back(fallback_location: root_path)
    end

    def update
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      @watch_list.update(watch_list_params)

      if @watch_list.save
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: DataCycleCore::WatchList.model_name.human(count: 1, locale: DataCycleCore.ui_language), locale: DataCycleCore.ui_language

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

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: DataCycleCore::WatchList.model_name.human(count: 1, locale: DataCycleCore.ui_language), locale: DataCycleCore.ui_language
      redirect_to root_path
    end

    def remove_item
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      @content_object = DataCycleCore::Thing.find(params[:hashable_id])
      @content_object.watch_lists.destroy(@watch_list) unless @content_object.nil? || @watch_list.nil?

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :removedFrom, scope: [:controllers, :success], data: @watch_list.name, locale: DataCycleCore.ui_language)) }
        format.js
      end
    end

    def add_item
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      @content_object = DataCycleCore::Thing.find(params[:hashable_id])
      @content_object.watch_lists << @watch_list unless @content_object.nil? || @watch_list.nil?

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :addedTo, scope: [:controllers, :success], data: @watch_list.name, locale: DataCycleCore.ui_language)) }
        format.js
      end
    end

    def bulk_edit
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      authorize!(:bulk_edit, @watch_list)

      @shared_properties = @watch_list.things.shared_ordered_properties(current_user)
      @shared_template_features = @watch_list.things.shared_template_features

      I18n.with_locale(params[:locale]) do
        @locale = I18n.locale

        redirect_to(watch_list_path(@watch_list), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return unless can?(:bulk_edit, @watch_list) && @watch_list.things.all? { |t| can?(:edit, t) }

        render && return
      end
    end

    def bulk_update
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      authorize!(:bulk_edit, @watch_list)

      @shared_properties = @watch_list.things.shared_ordered_properties(current_user)
      @shared_template_features = @watch_list.things.shared_template_features

      template_hash = { name: 'Generic', type: 'object', schema_type: 'Generic', content_type: 'entity', features: @shared_template_features, properties: @shared_properties.slice(*params['bulk_update']&.keys) }.stringify_keys
      object_params = content_params(template_hash)

      if object_params.dig(:datahash).blank?
        flash[:error] = I18n.t(:no_selected_attributes, scope: [:controllers, :error], locale: DataCycleCore.ui_language)
        render(js: "window.location.href = '#{watch_list_path(@watch_list)}';") && return
      end

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], template_hash)

      I18n.with_locale(params[:locale]) do
        unless can?(:bulk_edit, @watch_list) && @watch_list.things.all? { |t| can?(:update, t) }
          flash[:error] = I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language
          render(js: "window.location.href = '#{watch_list_path(@watch_list)}';") && return
        end

        template_hash.dig('properties')&.each_key do |k|
          datahash[k] ||= nil
        end

        update_items = @watch_list.things.joins(:translations).where(thing_translations: { locale: I18n.locale })
        item_count = update_items.size
        errors = []
        skip_update_names = @watch_list.things.where.not(id: update_items.ids).map { |c| I18n.with_locale(c.first_available_locale) { c.try(:title) || '__unnamed__' } }

        ActionCable.server.broadcast "bulk_update_#{@watch_list.id}_#{current_user.id}", progress: 0, items: item_count
        update_items.find_each.with_index do |content, index|
          valid = content.set_data_hash(data_hash: datahash, current_user: current_user, partial_update: true)
          errors << valid[:error] if valid[:error].present?
          ActionCable.server.broadcast "bulk_update_#{@watch_list.id}_#{current_user.id}", progress: index + 1, items: item_count
        end

        if errors.present?
          flash[:error] = errors.join(', ')
        else
          flash[:success] = I18n.t :bulk_updated, scope: [:controllers, :success], locale: DataCycleCore.ui_language
          flash[:success] += I18n.t :bulk_updated_skipped_html, scope: [:controllers, :info], data: skip_update_names.join(', '), locale: DataCycleCore.ui_language if skip_update_names.present?
        end

        if params[:new_locale].present?
          render(js: "window.location.href = '#{bulk_edit_watch_list_path(@watch_list, locale: params[:new_locale])}';") && return
        else
          render(js: "window.location.href = '#{watch_list_path(@watch_list)}';") && return
        end
      end
    end

    def validate
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      @shared_properties = @watch_list.things.shared_ordered_properties(current_user)
      @shared_template_features = @watch_list.things.shared_template_features

      render json: { warning: { content: ['content not found'] } } && return if params[:thing].blank?

      template_hash = { name: 'Generic', type: 'object', schema_type: 'Generic', content_type: 'entity', features: @shared_template_features, properties: @shared_properties }.stringify_keys

      object_params = content_params(template_hash)
      translation_values = object_params[:translations]&.values&.first || {}

      datahash = DataCycleCore::DataHashService.flatten_datahash_value((object_params[:datahash] || {}).merge(translation_values), template_hash)

      validator = DataCycleCore::MasterData::ValidateData.new
      valid = validator.validate(datahash, template_hash)

      render json: valid.to_json
    end

    def download
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      authorize! :download, @watch_list

      download_items = @watch_list.things.all.to_a.select do |thing|
        can? :download, thing
      end

      download_zip(@watch_list, download_items)
    end

    private

    def watch_list_params
      params.require(:watch_list).permit(:name, user_group_ids: [], user_ids: [])
    end

    def hashable_params
      params.permit(:hashable_id, :hashable_type)
    end

    def content_params(property_hash)
      datahash = DataCycleCore::DataHashService.get_params_from_hash(property_hash)
      return {} if params[:thing].blank?
      params.require(:thing).permit(datahash: datahash)
    end
  end
end
