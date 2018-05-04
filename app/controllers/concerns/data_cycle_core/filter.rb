module DataCycleCore
  module Filter
    extend ActiveSupport::Concern

    def get_filtered_results(query = nil)
      @filters ||= params[:f].presence&.values&.reject { |f| f['v'].blank? } || []
      @language ||= params.fetch(:language, DataCycleCore.ui_language)

      if params[:search].blank?
        # @order_by = !params[:order].nil? && params[:order].split('_').first == 'udpated' ? 'updated_at' : 'updated_at'
        @order_by = 'updated_at'
        @order = !params[:order].nil? && params[:order].split('_').last == 'asc' ? 'ASC' : 'DESC'
        @order_string = 'boost DESC, ' + @order_by + ' ' + @order
      else
        # order by ranking
        @order_string = DataCycleCore::Filter::Search.get_order_by_query_string(params[:search])
      end

      if @filters.find { |f| f['t'] == 'order' }.blank?
        @filters.push(
          {
            't' => 'order',
            'v' => @order_string
          }
        )
      end

      query ||= DataCycleCore::Filter::Search.new(@language)

      @filters.presence&.each do |filter|
        query = query.send(filter['t'], filter['v']) if query.respond_to?(filter['t'])
      end

      @filters += @stored_filters if @stored_filters.present?

      @default_filters = @filters.select { |f| f['c'] == 'd' && f['t'] == 'classification_alias_ids' }
      @advanced_filters = @filters.select { |f| f['c'] == 'a' }
      @selected_classifications = @default_filters.map { |c| c['v'] }.flatten.compact.uniq
      @selected_classification_aliases = DataCycleCore::ClassificationAlias.select(:id, :name).where(id: @filters.select { |f| f['t'] == 'classification_alias_ids' }.map { |f| f['v'] }.flatten.compact.uniq).map { |c| [c.id, c.name] }.to_h

      @paginateObject = query.includes(content_data: [:display_classification_aliases, :translations, :watch_lists, :external_source]).page(params[:page])

      @total = @paginateObject.total_count

      @paginateObject.map(&:content_data)
    end

    def apply_filter(filter_id:, api_only: false)
      filter = DataCycleCore::StoredFilter.find(filter_id)
      raise ActiveRecord::RecordNotFound if api_only && !filter.api

      filter.update(updated_at: Time.zone.now)

      @language = filter.language
      @stored_filters = filter.parameters || []
      filter.apply
    end

    def save_filter(new_filter: nil)
      new_filter ||= DataCycleCore::StoredFilter.new
      new_filter.user_id = current_user.id
      new_filter.language = @language
      new_filter.name = filter_params[:name] if params[:stored_filter].present? && filter_params[:name].present? && new_filter.id.nil?
      new_filter.system = filter_params[:system] if params[:stored_filter].present? && filter_params[:system].present?
      new_filter.parameters = @filters if @filters.present?
      new_filter.save
      new_filter
    end

    private

    def set_default_filter
      @filters = params[:f].presence&.values&.reject { |f| f['v'].blank? } || []

      if DataCycleCore.features&.dig(:life_cycle, :tree_label).present? &&
         DataCycleCore.features&.dig(:life_cycle, :default_filter).present? &&
         helpers.life_cycle_items.present? &&
         @filters.none? { |f| f['n'] == DataCycleCore.features&.dig(:life_cycle, :tree_label) && f['v'].present? } &&
         params[:stored_filter].blank?

        @filters.push(
          {
            'c' => 'a',
            't' => 'classification_alias_ids',
            'n' => DataCycleCore.features&.dig(:life_cycle, :tree_label),
            'm' => 'i',
            'v' => [helpers.life_cycle_items&.dig(DataCycleCore.features&.dig(:life_cycle, :default_filter), :alias)&.id]
          }
        )
      end
    end

    def filter_params
      params.require(:stored_filter).permit(:id, :name, :system)
    end
  end
end
