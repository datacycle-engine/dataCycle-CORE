module DataCycleCore
  class BackendController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    authorize_resource :class => false         # from cancancan (authorize)

    def index
      @classification_array = []
      unless params[:classification].blank?
        params[:classification].each do |item|
          @classification_array.push(item['selected'])
        end
      end
      @language = params[:language]
      @language ||= "de" #default-language

      @order_by = !params[:order].nil? && params[:order].split('_').first == 'udpated' ? 'updated_at' : 'updated_at'
      @order = !params[:order].nil? && params[:order].split('_').last == 'asc' ? 'ASC' : 'DESC' 
      order_string = @order_by + ' ' + @order

      query = DataCycleCore::Filter::QueryIndex.new(language: @language)
      query = query.order(order_string)
      query = query.fulltext_search(params[:search]) unless params[:search].blank?
      query = query.with_classification_alias_ids(@classification_array) unless @classification_array.blank?

      @paginateObject = query.page(params[:page])
      @dataCycleObjects = @paginateObject.page_data

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
