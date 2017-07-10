module DataCycleCore
  class BackendController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Themenwelten", "", "/"

    def index
      @classification_array = []
      unless params[:classification].blank?
        params[:classification].each do |item|
          @classification_array.push(item['selected'])
        end
      end
      @language = params[:language]
      @language ||= "de" #default-language

      query_creative_work = DataCycleCore::Filter::CreativeWorkQueryBuilder.new(@language).order(updated_at: :desc)
      query_creative_work = query_creative_work.fulltext_search(params[:search]) unless params[:search].blank?
      query_creative_work = query_creative_work.with_classification_alias_ids(@classification_array) unless @classification_array.blank?

      query_person = DataCycleCore::Filter::PersonQueryBuilder.new(@language).order(updated_at: :desc)
      query_person = query_person.fulltext_search(params[:search]) unless params[:search].blank?


      query = query_creative_work
      # concatinate results
      #query = [query_creative_work.query ,query_person.query]

      #@dataCycleObjects = Kaminari.paginate_array(query).page(params[:page]).per(10)
      @dataCycleObjects = query.page(params[:page])

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      @creativeWork = CreativeWork.new

    end

    def settings
      render layout: "data_cycle_core/frontend"
    end

    def vue

    end

  end
end
