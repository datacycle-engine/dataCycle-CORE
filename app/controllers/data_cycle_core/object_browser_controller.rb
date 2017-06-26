module DataCycleCore
  class ObjectBrowserController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)

    def show
      @@default_per = 50

      @language = params[:language] unless params[:language].blank?
      @language ||= "de"

      query = DataCycleCore::Filter::ImageQueryBuilder.new
      query = query.with_locale(@language)
      query = query.fulltext_search(params[:search]) unless params[:search].blank?

      @per = params[:per] unless params[:per].blank?
      @per ||= @@default_per

      total = query.count

      pages = total.fdiv(@per.to_i).ceil

      unless params[:page].blank?
        @page = params[:page]
        @page = pages if params[:page].to_i > pages
      end
      @page ||= 1

      @images = query.page(@page).per(@per)

      render :json => @images
    end

  end
end