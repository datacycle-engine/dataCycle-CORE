module DataCycleCore
  class Api::V1::WatchListsController < Api::V1::ApiBaseController

    @@default_per = 50

    # method to get all Images in all available languages
    def index
      query = DataCycleCore::WatchList.all

      @per = params[:per] unless params[:per].blank?
      @per ||= @@default_per

      @total = query.count
      pages = @total.fdiv(@per.to_i).ceil

      unless params[:page].blank?
        @page = params[:page]
        @page = pages if params[:page].to_i > pages
      end
      @page ||= 1

      @watch_lists = query.page(@page).per(@per)
    end
  end
end
