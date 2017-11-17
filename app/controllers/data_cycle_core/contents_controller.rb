module DataCycleCore
  class ContentsController < ApplicationController
    before_action :udpate_trail_in_session, only: :show
    before_action :set_watch_list

    private
    def udpate_trail_in_session
      if params[:trail]
        session[:trail] = params[:trail]
      else
        session.delete(:trail)
      end
    end

    def set_watch_list
      @watch_list = DataCycleCore::WatchList.find(params[:watch_list_id]) if params[:watch_list_id]
    end
  end
end
