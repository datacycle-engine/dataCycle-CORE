module DataCycleCore
  class ObjectBrowserController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)

    def show
      @@default_per = 50

      @language = params[:language] unless params[:language].blank?
      @language ||= "de"

      @type = params[:type] unless params[:type].blank?
      @type ||= "image"

      if @type == "image"

        query = DataCycleCore::Filter::ImageQueryBuilder.new(@language)
        query = query.only_images
        query = query.fulltext_search(params[:search]) unless params[:search].blank?

      elsif @type == "person"

        query = DataCycleCore::Filter::PersonQueryBuilder.new(@language)
        query = query.fulltext_search(params[:search]) unless params[:search].blank?

      elsif @type == "place"

        query = DataCycleCore::Filter::PlaceQueryBuilder.new(@language)
        query = query.only_frontend_valid
        query = query.fulltext_search(params[:search]) unless params[:search].blank?

      else

        query = DataCycleCore::Filter::ImageQueryBuilder.new(@language)
        query = query.fulltext_search(params[:search]) unless params[:search].blank?

      end

      @per = params[:per] unless params[:per].blank?
      @per ||= @@default_per

      total = query.count

      pages = total.fdiv(@per.to_i).ceil

      unless params[:page].blank?
        @page = params[:page]
        @page = pages if params[:page].to_i > pages
      end
      @page ||= 1

      @results = query.page(@page).per(@per)

      render :json => { results: @results, total: total }
    end

  end
end
