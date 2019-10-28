# frozen_string_literal: true

module DataCycleCore
  module Filter
    extend ActiveSupport::Concern

    def get_filtered_results(query = nil, user_filter = false)
      filters
      @language ||= Array(params.fetch(:language) { [current_user.default_locale] })

      @order_string ||= DataCycleCore::Filter::Search.get_order_by_query_string(@filters.find { |f| f['t'] == 'fulltext_search' }&.dig('v'))

      if @filters.none? { |f| f['t'] == 'order' }
        @filters.push(
          {
            't' => 'order',
            'v' => @order_string
          }
        )
      end

      query_params = @language.include?('all') ? [nil, DataCycleCore::Thing] : [@language]
      query ||= DataCycleCore::Filter::Search.new(*query_params).exclude_templates_embedded

      # add default filters for user role if any exist
      @filters = current_user.default_filter(@filters) if user_filter

      @filters.presence&.each do |filter|
        t = filter['m'] == 'e' ? "not_#{filter['t']}" : filter['t']
        next unless query.respond_to?(t)

        if query.method(t)&.parameters&.size == 2
          query = query.send(t, filter['v'], filter['q'].presence || filter['n'].presence)
        else
          query = query.send(t, filter['v'])
        end
      end

      # add existing stored filter params
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
      @order_string = filter.parameters.find { |f| f['t'] == 'order' }&.dig('v')

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

    def filters
      @filters ||= params[:f].presence&.values&.reject { |f| f['v'].is_a?(Hash) ? f['v'].all? { |_, v| v.blank? } : f['v'].blank? } || []
    end

    def set_instance_variables_by_view_mode(query: nil, user_filter: false)
      case @mode
      when 'tree'
        @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(tree_view_params[:ctl_id])

        if tree_view_params[:con_id].present?
          @classification_parent_tree = DataCycleCore::ClassificationTree.find(tree_view_params[:cpt_id])
          @container = DataCycleCore::Thing.find(tree_view_params[:con_id])
          @order_string = 'things.boost DESC, things.template_name ASC, things.updated_at DESC'
          @contents = get_filtered_results(query, user_filter)
            .part_of(@container.id)
            .distinct_by_content_id(@order_string)
            .content_includes
            .page(params[:page])

          @page = @contents.current_page
          @total_count = @contents.total_count
          @total_pages = @contents.total_pages
        elsif tree_view_params[:ct_id].present?
          @classification_tree = DataCycleCore::ClassificationTree.find(tree_view_params[:ct_id])
          @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees
          @classification_trees = @classification_trees.where.not(classification_aliases: { internal_name: DataCycleCore.excluded_filter_classifications }) if @classification_tree_label.name == 'Inhaltstypen'
          @classification_trees = @classification_trees
            .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
            .order('classification_aliases.internal_name')
            .page(params[:tree_page])

          @order_string = 'things.boost DESC, things.template_name ASC, things.updated_at DESC'
          @contents = get_filtered_results(query, user_filter)
            .with_classification_alias_ids_without_recursion(@classification_tree.sub_classification_alias.id)
            .distinct_by_content_id(@order_string)
            .content_includes
            .page(params[:page])

          @page = @contents.current_page
          @total_count = @contents.total_count
          @total_pages = @contents.total_pages
        else
          @classification_trees = @classification_tree_label.classification_trees
            .where(parent_classification_alias: nil)
            .joins(:sub_classification_alias)
          @classification_trees = @classification_trees.where.not(classification_aliases: { internal_name: DataCycleCore.excluded_filter_classifications }) if @classification_tree_label.name == 'Inhaltstypen'
          @classification_trees = @classification_trees
            .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
            .order('classification_aliases.internal_name')
            .page(params[:tree_page])
        end

        @tree_page = @classification_trees&.current_page
        @tree_total_pages = @classification_trees&.total_pages
        @content_count = @classification_trees&.map { |c|
          [
            c.id,
            get_filtered_results(query, user_filter)
              .with_classification_alias_ids_without_recursion(c.sub_classification_alias.id)
              .count_distinct
          ]
        }.to_h

        @contents&.where(content_type: 'container')&.each do |con|
          @content_count[con.id] = get_filtered_results(query, user_filter)
            .part_of(con.id)
            .count_distinct
        end
      else
        @contents = get_filtered_results(query, user_filter)
        tmp_count = @contents.count_distinct
        @contents = @contents.distinct_by_content_id(@order_string).content_includes.page(params[:page])
        @total = @contents.instance_variable_set(:@total_count, tmp_count)
      end
    end

    private

    def set_default_filter
      filters

      if DataCycleCore::Feature::LifeCycle.tree_label.present? &&
         DataCycleCore::Feature::LifeCycle.ordered_classifications.present? &&
         DataCycleCore::Feature::LifeCycle.default_filter.present? &&
         @filters.none? { |f| f['n'] == DataCycleCore::Feature::LifeCycle.tree_label && f['v'].present? } &&
         (@stored_filters || []).none? { |f| f['n'] == DataCycleCore::Feature::LifeCycle.tree_label && f['v'].present? }

        @filters.push(
          {
            'c' => 'a',
            't' => 'classification_alias_ids',
            'n' => DataCycleCore::Feature::LifeCycle.tree_label,
            'm' => 'i',
            'v' => [DataCycleCore::Feature::LifeCycle.ordered_classifications.dig(DataCycleCore::Feature::LifeCycle.default_filter, :alias_id)]
          }
        )
      end
    end

    def load_stored_filter
      @query = apply_filter(filter_id: params[:stored_filter])
    end

    def load_last_filter
      params[:stored_filter] = current_user.stored_filters.order(updated_at: :desc)&.first&.id
    end

    def filter_params
      params.require(:stored_filter).permit(:id, :name, :system)
    end

    def tree_view_params
      params.permit(:ct_id, :con_id, :ctl_id, :cpt_id)
    end
  end
end
