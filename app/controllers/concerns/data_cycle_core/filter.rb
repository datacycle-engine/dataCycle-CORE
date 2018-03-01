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

      @classification_array.push(*params[:classification]&.map { |c| c[:selected] }&.flatten)

      @language = params.fetch(:language, 'de')

      if params[:search].blank?
        # @order_by = !params[:order].nil? && params[:order].split('_').first == 'udpated' ? 'updated_at' : 'updated_at'
        @order_by = 'updated_at'
        @order = !params[:order].nil? && params[:order].split('_').last == 'asc' ? 'ASC' : 'DESC'
        @order_string = 'boost DESC, ' + @order_by + ' ' + @order
      else
        # order by ranking
        @order_string = DataCycleCore::Filter::Search.get_order_by_query_string(params[:search])
      end

      query = DataCycleCore::Filter::Search.new(@language).in_validity_period

      # optional querymethods
      query = query.send(method_name, parameters) unless method_name.blank?

      query = query.order(@order_string)
      query = query.fulltext_search(params[:search]) unless params[:search].blank?

      if @classification_array.present?
        @with_classification_alias_ids = parse_classifications(@classification_array)
        @with_classification_alias_ids.each_value do |class_array|
          query = query.with_classification_alias_ids(class_array)
        end
      end

      @total = query.count(:id)

      @paginateObject = query.includes(content_data: [:display_classification_aliases, :translations, :watch_lists, :external_source]).page(params[:page])

      @paginateObject.map(&:content_data)
    end

    def apply_filter(filter_id:, api_only: false)
      filter = DataCycleCore::StoredFilter.find(filter_id)
      raise ActiveRecord::RecordNotFound if api_only && !filter.api

      filter.update(updated_at: Time.zone.now)

      params[:language] = filter.language
      @language = filter.language

      unless filter.parameters['fulltext_search'].blank?
        params[:search] = filter.parameters['fulltext_search']
      end

      unless filter.parameters['with_classification_alias_ids'].blank?
        @classification_array = filter.parameters['with_classification_alias_ids'].map { |_, value| value }.flatten
      end

      query = filter.apply
      @total = query.count(:id)
      query
    end

    def save_filter(method_name: nil, parameters: nil)
      new_filter = DataCycleCore::StoredFilter.new
      new_filter.user_id = current_user.id
      new_filter.language = @language
      new_filter.name = filter_params[:stored_filter_name] if filter_params[:stored_filter_name].present?
      new_filter.system = filter_params[:stored_filter_system]
      new_filter.api = filter_params[:stored_filter_api]
      new_filter.parameters = {}
      new_filter.parameters[:in_validity_period] = Time.zone.now
      new_filter.parameters[:order] = @order_string if @order_string.present?
      new_filter.parameters[:fulltext_search] = params[:search] if params[:search].present?
      new_filter.parameters[:with_classification_alias_ids] = @with_classification_alias_ids if @with_classification_alias_ids.present?
      new_filter.parameters[method_name.to_sym] = parameters if parameters.present?
      new_filter.save
      new_filter
    end

    private

    def filter_params
      params.permit(:stored_filter_name, :stored_filter_system, :stored_filter_api)
    end
  end
end
