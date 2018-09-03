# frozen_string_literal: true

module DataCycleCore
  module Filter
    extend ActiveSupport::Concern

    def get_filtered_results(query = nil)
      @filters ||= params[:f].presence&.values&.reject { |f| f['v'].blank? } || []
      @language ||= params.fetch(:language, [current_user.default_locale])

      if @filters.any? { |f| f['t'] == 'fulltext_search' }
        @order_string ||= DataCycleCore::Filter::Search.get_order_by_query_string(@filters.find { |f| f['t'] == 'fulltext_search' }&.dig('v'))
      else
        @order_string ||= { boost: :desc, updated_at: :desc }
      end

      if @filters.none? { |f| f['t'] == 'order' }
        @filters.push(
          {
            't' => 'order',
            'v' => @order_string
          }
        )
      end

      query_params = @language.include?('all') ? [nil, DataCycleCore::Search.all] : [@language]
      query ||= DataCycleCore::Filter::Search.new(*query_params)

      @filters.presence&.each do |filter|
        query = query.send(filter['t'], filter['v']) if query.respond_to?(filter['t'])
      end

      @filters.concat(@stored_filters) if @stored_filters.present?

      @default_filters = @filters.select { |f| f['c'] == 'd' && f['t'] == 'classification_alias_ids' }
      @advanced_filters = @filters.select { |f| f['c'] == 'a' }
      @selected_classifications = @default_filters.map { |c| c['v'] }.flatten.compact.uniq
      @selected_classification_aliases = DataCycleCore::ClassificationAlias
        .where(
          id: @filters
            .select { |f| f['t'] == 'classification_alias_ids' }
            .map { |f| f['v'] }
            .flatten
            .compact
            .uniq
        )
        .map { |c| [c.id, c] }.to_h

      query
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
      new_filter.language = [@language].flatten
      new_filter.name = filter_params[:name] if params[:stored_filter].present? && filter_params[:name].present? && new_filter.id.nil?
      new_filter.system = filter_params[:system] if params[:stored_filter].present? && filter_params[:system].present?
      new_filter.parameters = @filters if @filters.present?
      new_filter.save
      new_filter
    end

    private

    def set_default_filter
      @filters = params[:f].presence&.values&.reject { |f| f['v'].blank? } || []

      if DataCycleCore::Feature::LifeCycle.tree_label.present? &&
         DataCycleCore::Feature::LifeCycle.ordered_classifications.present? &&
         DataCycleCore::Feature::LifeCycle.default_filter.present? &&
         @filters.none? { |f| f['n'] == DataCycleCore::Feature::LifeCycle.tree_label && f['v'].present? } &&
         params[:stored_filter].blank?

        @filters.push(
          {
            'c' => 'a',
            't' => 'classification_alias_ids',
            'n' => DataCycleCore::Feature::LifeCycle.tree_label,
            'm' => 'i',
            'v' => [DataCycleCore::Feature::LifeCycle.ordered_classifications.dig(DataCycleCore::Feature::LifeCycle.default_filter, :alias)&.id]
          }
        )
      end
    end

    def filter_params
      params.require(:stored_filter).permit(:id, :name, :system)
    end
  end
end
