# frozen_string_literal: true

module DataCycleCore
  module Filter
    extend ActiveSupport::Concern

    def get_filtered_results(query = nil, user_filter = false)
      @filters = pre_filters.dup
      query = query.dup if query.present?
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
        case filter['m']
        when 'e'
          t = "not_#{filter['t']}"
        when 'g'
          t = "greater_#{filter['t']}"
        when 'l'
          t = "lower_#{filter['t']}"
        when 's'
          t = "like_#{filter['t']}"
        else
          t = filter['t']
        end

        t = "#{t}_with_subtree" if can?(:experimental_features, :dash_board) && (filter['t'] == 'classification_alias_ids' || filter['t'] == 'not_classification_alias_ids')

        next unless query.respond_to?(t)
        if query.method(t)&.parameters&.size == 3
          query = query.send(t, filter['v'], filter['q'].presence, filter['n'].presence)
        elsif query.method(t)&.parameters&.size == 2
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

    def pre_filters
      @pre_filters ||= params[:f].presence&.values&.reject { |f| f['v'].is_a?(Hash) ? f['v'].all? { |_, v| v.blank? } : f['v'].blank? } || []
    end

    def set_instance_variables_by_view_mode(query: nil, user_filter: false)
      set_view_mode

      return @total_count = total_count(query: query, user_filter: user_filter) if count_only_params[:count_only].present?

      case @mode
      when 'tree'
        @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(mode_params[:ctl_id])

        if mode_params[:con_id].present?
          @classification_parent_tree = DataCycleCore::ClassificationTree.find(mode_params[:cpt_id])
          @container = DataCycleCore::Thing.find(mode_params[:con_id])
          @order_string = 'things.boost DESC, things.template_name ASC, things.updated_at DESC'
          @contents = get_filtered_results(query, user_filter)
            .part_of(@container.id)
          tmp_count = @contents.count_distinct
          @contents = @contents.distinct_by_content_id(@order_string)
            .content_includes
            .page(params[:page])

          @page = @contents.current_page
          @total_count = @contents.instance_variable_set(:@total_count, tmp_count)
          @total_pages = @contents.total_pages
        elsif mode_params[:ct_id].present?
          @classification_tree = DataCycleCore::ClassificationTree.find(mode_params[:ct_id])
          @classification_trees = @classification_tree.sub_classification_alias.sub_classification_trees
          @classification_trees = @classification_trees.where.not(classification_aliases: { internal_name: DataCycleCore.excluded_filter_classifications }) if @classification_tree_label.name == 'Inhaltstypen'
          @classification_trees = @classification_trees
            .includes(sub_classification_alias: [:sub_classification_trees, :classifications, :external_source])
            .order('classification_aliases.internal_name')
            .page(params[:tree_page])

          @order_string = 'things.boost DESC, things.template_name ASC, things.updated_at DESC'
          @contents = get_filtered_results(query, user_filter)
            .with_classification_alias_ids_without_recursion(@classification_tree.sub_classification_alias.id)
          tmp_count = @contents.count_distinct
          @contents = @contents.distinct_by_content_id(@order_string)
            .content_includes
            .page(params[:page])

          @page = @contents.current_page
          @total_count = @contents.instance_variable_set(:@total_count, tmp_count)
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
          get_filtered_results(query, user_filter) # set default parameters for filters
        end

        @tree_page = @classification_trees&.current_page
        @tree_total_pages = @classification_trees&.total_pages
      else
        @contents = get_filtered_results(query, user_filter)
        @contents = @contents.distinct_by_content_id(@order_string).content_includes.page(params[:page]).without_count
      end
    end

    private

    def set_view_mode
      if mode_params[:mode].in?(['list', 'tree'])
        @mode = mode_params[:mode].to_s
      else
        @mode = 'grid'
      end
    end

    def total_count(query: nil, user_filter: nil)
      @count_only = true
      @target = count_only_params[:target]
      classification_tree = DataCycleCore::ClassificationTree.find(mode_params[:ct_id]) if mode_params[:ct_id].present?
      total_count = get_filtered_results(query, user_filter)
      @count_mode = count_only_params[:count_mode]
      @content_class = count_only_params[:content_class]

      case @count_mode
      when 'container'
        total_count = total_count.part_of(mode_params[:con_id])
      when 'classification_alias'
        total_count = total_count.with_classification_alias_ids_without_recursion(classification_tree.sub_classification_alias.id)
      when 'ca_recursive'
        total_count = total_count.classification_alias_ids(classification_tree.sub_classification_alias.id)
      when 'classification_tree_label'
        ca_label = DataCycleCore::ClassificationTreeLabel.find(mode_params[:ctl_id])
        total_count = total_count.classification_tree_ids(ca_label.id)
      end

      total_count.count_distinct
    end

    def set_default_filter
      @pre_filters = pre_filters.dup

      if DataCycleCore::Feature::LifeCycle.tree_label.present? &&
         DataCycleCore::Feature::LifeCycle.ordered_classifications.present? &&
         DataCycleCore::Feature::LifeCycle.default_filter.present? &&
         @pre_filters.none? { |f| f['n'] == DataCycleCore::Feature::LifeCycle.tree_label && f['v'].present? } &&
         (@stored_filters || []).none? { |f| f['n'] == DataCycleCore::Feature::LifeCycle.tree_label && f['v'].present? }

        @pre_filters.push(
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

    def mode_params
      params.permit(:mode, :ct_id, :con_id, :ctl_id, :cpt_id)
    end

    def count_only_params
      params.permit(:target, :count_only, :count_mode, :content_class)
    end
  end
end
