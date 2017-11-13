module DataCycleCore
  class BackendController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    authorize_resource :class => false         # from cancancan (authorize)

    def index
      @classification_array ||= []

      unless params[:classification].blank?
        params[:classification].each do |item|
          @classification_array.push(item['selected'])
        end
      end
      @language = params[:language]
      @language ||= "de" #default-language

      if params[:search].blank?
        @order_by = !params[:order].nil? && params[:order].split('_').first == 'udpated' ? 'updated_at' : 'updated_at'
        @order = !params[:order].nil? && params[:order].split('_').last == 'asc' ? 'ASC' : 'DESC'
        order_string = 'boost DESC, ' + @order_by + ' ' + @order
      else
        # order by ranking
        search_string = params[:search].split(" ").join("%")
        order_string = "boost * (
          8 * similarity(classification_string,'%#{search_string}%') +
          4 * similarity(headline, '%#{search_string}%') +
          2 * ts_rank_cd(words, plainto_tsquery('simple', '#{params[:search].squish}'),16) +
          1 * similarity(full_text, '%#{search_string}%'))
          DESC NULLS LAST,
          updated_at DESC"
      end


      query = DataCycleCore::Filter::Search.new(@language).in_validity_period
      query = query.order(order_string)
      query = query.fulltext_search(params[:search]) unless params[:search].blank?

      unless @classification_array.blank?
        parse_classifications(@classification_array).each do |tree_label, class_array|
          query = query.with_classification_alias_ids(class_array)
        end
      end

      @paginateObject = query.page(params[:page])
      @dataCycleObjects = @paginateObject.map(&:content_data)

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

    private

    def parse_classifications(class_array)
      grouping_class = {}
      class_array.each do |class_id|
        name = DataCycleCore::ClassificationAlias.find(class_id).classification_tree_label.name
        grouping_class[name] ||= []
        grouping_class[name].push(class_id)
      end
      grouping_class
    end

  end
end
