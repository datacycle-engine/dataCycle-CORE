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
      @language ||= "de" #default-language

      if params[:search].blank?
        @order_by = !params[:order].nil? && params[:order].split('_').first == 'udpated' ? 'updated_at' : 'updated_at'
        @order = !params[:order].nil? && params[:order].split('_').last == 'asc' ? 'ASC' : 'DESC'
        @order_string = 'boost DESC, ' + @order_by + ' ' + @order
      else
        # order by ranking
        search_string = params[:search].split(" ").join("%")
        @order_string = "boost * (
          8 * similarity(classification_string,'%#{search_string}%') +
          4 * similarity(headline, '%#{search_string}%') +
          2 * ts_rank_cd(words, plainto_tsquery('simple', '#{params[:search].squish}'),16) +
          1 * similarity(full_text, '%#{search_string}%'))
          DESC NULLS LAST,
          updated_at DESC"
      end

      query = DataCycleCore::Filter::Search.new(@language).in_validity_period

      # optional querymethods
      query = query.send(method_name, parameters) unless method_name.blank?

      query = query.order(@order_string)
      query = query.fulltext_search(params[:search]) unless params[:search].blank?

      unless @classification_array.blank?
        @with_classification_alias_ids = parse_classifications(@classification_array)
        @with_classification_alias_ids.each do |tree_label, class_array|
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

    def apply_filter(filter_id:)
      filter = DataCycleCore::StoredFilter.find(filter_id)

      params[:language] = filter.language
      @language = filter.language

      unless filter.parameters['fulltext_search'].blank?
        params[:search] = filter.parameters['fulltext_search']
      end

      unless filter.parameters['with_classification_alias_ids'].blank?
        @classification_array = filter.parameters['with_classification_alias_ids'].map{|_,value| value}.flatten
      end

      query = filter.apply
      @total = query.count(:id)
      @paginateObject = query.page(1)
      @paginateObject.includes(content_data: [:display_classification_aliases, :translations, :watch_lists]).map(&:content_data)
    end

    def save_filter(method_name: nil, parameters: nil)
      new_filter = DataCycleCore::StoredFilter.new
      new_filter.user_id = current_user.id
      new_filter.language = @language
      new_filter.parameters = {}
      new_filter.parameters[:in_validity_period] = Time.zone.now
      new_filter.parameters[:order] = @order_string unless @order_string.blank?
      new_filter.parameters[:fulltext_search] = params[:search] unless params[:search].blank?
      new_filter.parameters[:with_classification_alias_ids] = @with_classification_alias_ids unless @with_classification_alias_ids.blank?
      new_filter.parameters[method_name.to_sym] = parameters unless parameters.blank?
      new_filter.save
    end

  end
end
