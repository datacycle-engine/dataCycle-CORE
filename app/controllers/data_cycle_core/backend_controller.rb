module DataCycleCore
  class BackendController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def index
      @language = params[:language]
      @language ||= "de" #default-language

      query = DataCycleCore::Filter::CreativeWorkQueryBuilder.new(@language).order(updated_at: :desc)
      query = query.fulltext_search(params[:search]) unless params[:search].blank?

      @dataCycleObjects = query.page(params[:page])

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      @creativeWork = CreativeWork.new

    end

    def settings

    end

    def vue

    end

  end
end
