module DataCycleCore
  class WatchListsController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    load_and_authorize_resource         # from cancancan (authorize)

    def index
      @watch_lists = current_user.watch_lists
    end

    def show
      session[:trail] = params[:trail] unless params[:trail].nil?
      @watch_list = DataCycleCore::WatchList.find_by(id: params[:id])

      if @watch_list.nil?
        redirect_to root
      end

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      render layout: "data_cycle_core/watch_lists_edit"

    end

    def new
      @watch_list = DataCycleCore::WatchList.new
    end

    def create
      @watch_list = current_user.watch_lists.build(watch_list_params)

      respond_to do |format|
        if !@watch_list.nil? && @watch_list.save
          format.json { render json: { headline: @watch_list.headline, url: addItem_watch_list_path(@watch_list, hashable_params) } }
          format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :created, scope: [:controllers, :success], data: 'Merkliste')) }
        else
          format.json { render json: { error: "Konnte nicht gespeichert werden." } }
          format.html { redirect_back(fallback_location: root_path) }
        end
      end
    end

    def edit
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      if params[:data_id].nil?
        render layout: "data_cycle_core/watch_lists_edit"
      else
        add_remove_data params
        redirect_back(fallback_location: root_path)
      end
    end

    def update
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      update_params = {:headline => watch_list_params[:headline]}
      @watch_list.update_attributes(update_params)

      if @watch_list.save
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Merkliste'

        if Rails.env.development?
          redirect_to edit_watch_list_path(@watch_list) if Rails.env.development?
        else
          redirect_to watch_list_path(@watch_list, trail: session[:trail])
        end

      else
        render 'edit'
      end
    end

    def destroy
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      @watch_list.destroy

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Merkliste'
      redirect_to watch_lists_path
    end

    def removeItem
      watch_list = DataCycleCore::WatchList.find(params[:id])
      content_object = params[:hashable_type].constantize.find(params[:hashable_id])

      unless content_object.nil? || watch_list.nil?
        content_object.watch_lists.delete(watch_list)
      end

      respond_to do |format|
        format.json { render json: { url: addItem_watch_list_path(watch_list, hashable_params), count: content_object.watch_lists.by_user(current_user).count, headline: watch_list.headline } }
        format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :removedFrom, scope: [:controllers, :success], data: watch_list.headline)) }
      end

    end

    def addItem
      watch_list = DataCycleCore::WatchList.find(params[:id])
      content_object = params[:hashable_type].constantize.find(params[:hashable_id])

      unless content_object.nil? || watch_list.nil?
        content_object.watch_lists << watch_list
      end

      respond_to do |format|
        format.json { render json: { url: removeItem_watch_list_path(watch_list, hashable_params), count: content_object.watch_lists.by_user(current_user).count, headline: watch_list.headline } }
        format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :addedTo, scope: [:controllers, :success], data: watch_list.headline)) }
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
