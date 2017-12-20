module DataCycleCore
  class ContentsController < ApplicationController
    before_action :set_watch_list

    def render_embedded_object
      respond_to(:js)
    end

    private

    def set_watch_list
      watch_list = DataCycleCore::WatchList.find(params[:watch_list_id]) if params[:watch_list_id]
      @watch_list = watch_list if can?(:manage, watch_list)
    end
  end
end
