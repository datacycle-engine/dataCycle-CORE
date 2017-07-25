module DataCycleCore
  class WatchListsController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    before_action :check_permission, only: [:show, :edit, :udpate, :destroy, :removeItem, :addItem]
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Merklisten", "", "/watch_lists"

    def index
      @watch_lists = current_user.watch_lists
    end

    def show
      @watch_list = DataCycleCore::WatchList.find_by(id: params[:id])
      set_breadcrumb_for @watch_list

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

      if !@watch_list.nil? && @watch_list.save
        set_breadcrumb_for @watch_list
        flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Merkliste'
        redirect_to :back
      else
        redirect_to :back
      end
    end

    def edit
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      set_breadcrumb_for @watch_list
      add_breadcrumb '<i aria-hidden="true" class="fa fa-pencil"></i> Bearbeiten'.html_safe, "", watch_list_path(@watch_list)

      if params[:data_id].nil?
        render layout: "data_cycle_core/watch_lists_edit"
      else
        add_remove_data params
        redirect_to :back
      end        
    end

    def update
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      set_breadcrumb_for @watch_list
      add_breadcrumb "", "Edit", creative_work_path(@watch_list)

      update_params = {:headline => watch_list_params[:headline]}
      @watch_list.update_attributes(update_params)

      if @watch_list.save
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Merkliste'

        if Rails.env.development?
          redirect_to edit_watch_list_path(@watch_list) if Rails.env.development?
        else
          redirect_to @watch_list
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
      data = get_data(watch_list, params[:data_type], params[:data_id])
      watch_list.watch_list_data_hashes.destroy(data)

      redirect_to :back
    end

    def addItem
      watch_list = DataCycleCore::WatchList.find(params[:id])
      data = get_data(watch_list, params[:data_type], params[:data_id])
      if data.empty?
        watch_list.watch_list_data_hashes.build( :watch_list_id => watch_list.id, :hashable_id => params[:data_id], :hashable_type => params[:data_type] )
        watch_list.save
      end

      redirect_to :back
    end

    private

      def watch_list_params
        params.require(:watch_list).permit(:headline)
      end

      def get_data watch_list, type, id
        watch_list.watch_list_data_hashes.where('watch_list_id = ? AND hashable_type = ? AND hashable_id = ?', watch_list.id, type, id)
      end

      def set_breadcrumb_for watch_list
        #set_breadcrumb_for creativeWork.parent if creativeWork.parent
        add_breadcrumb 'Merkliste', watch_list.headline, watch_list_path(watch_list.id)
      end

      def check_permission
        if current_user != DataCycleCore::WatchList.find(params[:id]).user
          flash[:error] = I18n.t :no_permission, scope: [:controllers, :error]
          redirect_to root_path
        end
      end

  end
end
