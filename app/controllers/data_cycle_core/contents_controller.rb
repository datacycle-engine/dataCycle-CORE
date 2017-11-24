module DataCycleCore
  class ContentsController < ApplicationController
    before_action :set_watch_list

    private

    def set_watch_list
      watch_list = DataCycleCore::WatchList.find(params[:watch_list_id]) if params[:watch_list_id]
      @watch_list = watch_list if can?(:manage, watch_list)
    end
  end
end
