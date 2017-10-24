module DataCycleCore
  class ContentsController < ApplicationController
    before_action :udpate_trail_in_session, only: :show

    private
    def udpate_trail_in_session
      if params[:trail]
        session[:trail] = params[:trail]
      else
        session.delete(:trail)
      end
    end
  end
end
