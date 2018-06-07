# frozen_string_literal: true

module DataCycleCore
  class WatchListsController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user!   # from devise (authenticate)
    load_and_authorize_resource         # from cancancan (authorize)

    def index
      @paginate_object = current_user.watch_lists.page(params[:page])
    end

    def show
      @watch_list = DataCycleCore::WatchList.find_by(id: params[:id])

      redirect_to root if @watch_list.nil?

      @filters = params[:f].presence&.values&.reject { |f| f['v'].blank? } || []
      @filters.push(
        {
          't' => 'watch_list_id',
          'v' => @watch_list.id
        }
      )

      @paginate_object = get_filtered_results.content_includes.page(params[:page])
      @contents = @paginate_object.map(&:content_data)

      respond_to do |format|
        format.html
        format.json { redirect_to api_v1_collection_path(@watch_list) }
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
          format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :created, scope: [:controllers, :success], data: 'Merkliste', locale: DataCycleCore.ui_language)) }
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

      update_params = { headline: watch_list_params[:headline] }
      @watch_list.update_attributes(update_params)

      if @watch_list.save
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Merkliste', locale: DataCycleCore.ui_language

        if Rails.env.development?
          redirect_to edit_watch_list_path(@watch_list) if Rails.env.development?
        else
          redirect_to watch_list_path(@watch_list, watch_list_id: @watch_list)
        end

      else
        render 'edit'
      end
    end

    def destroy
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      @watch_list.destroy

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Merkliste', locale: DataCycleCore.ui_language
      redirect_to watch_lists_path
    end

    def remove_item
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      object_type = DataCycleCore.content_tables.map { |object| ('DataCycleCore::' + object.singularize.classify) }.find { |object| object == params[:hashable_type].classify }

      unless object_type.nil?
        @content_object = object_type.constantize.find(params[:hashable_id])

        @content_object.watch_lists.delete(@watch_list) unless @content_object.nil? || @watch_list.nil?
      end

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :removedFrom, scope: [:controllers, :success], data: @watch_list.headline, locale: DataCycleCore.ui_language)) }
        format.js
      end
    end

    def add_item
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      object_type = DataCycleCore.content_tables.map { |object| ('DataCycleCore::' + object.singularize.classify) }.find { |object| object == params[:hashable_type].classify }

      unless object_type.nil?
        @content_object = object_type.constantize.find(params[:hashable_id])

        @content_object.watch_lists << @watch_list unless @content_object.nil? || @watch_list.nil?
      end

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :addedTo, scope: [:controllers, :success], data: @watch_list.headline, locale: DataCycleCore.ui_language)) }
        format.js
      end
    end

    private

    def watch_list_params
      params.require(:watch_list).permit(:headline)
    end

    def hashable_params
      params.permit(:hashable_id, :hashable_type)
    end
  end
end
