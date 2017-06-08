module DataCycleCore
  class Api::V1::ImagesController < Api::V1::ApiBaseController

    @@default_per = 10

    # method to get all Images in all available languages
    def index
      query = DataCycleCore::Filter::ImageQueryBuilder.new.only_images

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
    end

    # method to query images per language and full-text-search
    def search
      @language = params[:language] unless params[:language].blank?
      @language ||= "de"

      query = DataCycleCore::Filter::ImageQueryBuilder.new.only_images
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
    end

    # method to show a particular Image with all languages
    def show
      @image = DataCycleCore::CreativeWork.where(id: params[:id]).first
    end

  end
end
