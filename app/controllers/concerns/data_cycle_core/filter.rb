module DataCycleCore
  module Filter
    extend ActiveSupport::Concern

    def parse_classifications(class_array)
      grouping_class = {}
      class_array.each do |class_id|
        name = DataCycleCore::ClassificationAlias.find(class_id).classification_tree_label.name
        grouping_class[name] ||= []
        grouping_class[name].push(class_id)
      end
      grouping_class
    end

    def get_filtered_results(method_name: nil, parameters: nil)
      @classification_array ||= []

      unless params[:classification].blank?
        params[:classification].each do |item|
          @classification_array.push(item['selected'])
        end
      end
      @language = params[:language]
      @language ||= 'de' # default-language

      if params[:search].blank?
        # @order_by = !params[:order].nil? && params[:order].split('_').first == 'udpated' ? 'updated_at' : 'updated_at'
        @order_by = 'updated_at'
        @order = !params[:order].nil? && params[:order].split('_').last == 'asc' ? 'ASC' : 'DESC'
        order_string = 'boost DESC, ' + @order_by + ' ' + @order
      else
        # order by ranking
        order_string = DataCycleCore::Filter::ObjectBrowserQueryBuilder.get_order_by_query_string(params[:search])
      end

      query = DataCycleCore::Filter::Search.new(@language).in_validity_period

      # optional querymethods
      query = query.send(method_name, parameters) unless method_name.blank?

      query = query.order(order_string)
      query = query.fulltext_search(params[:search]) unless params[:search].blank?

      unless @classification_array.blank?
        parse_classifications(@classification_array).each do |tree_label, class_array|
          query = query.with_classification_alias_ids(class_array)
        end
      end

      @total = query.count(:id)

      @paginateObject = query.page(params[:page])

      # if params[:mode].nil?
      #   @mode = "flex"
      # else
      #   @mode = params[:mode].to_s
      # end

      @paginateObject.includes(content_data: [:display_classification_aliases, :translations, :watch_lists]).map(&:content_data)
    end
  end
end
