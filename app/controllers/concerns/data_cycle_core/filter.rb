# frozen_string_literal: true

module DataCycleCore
  module Filter
    extend ActiveSupport::Concern
    DEFAULT_PAGE_SIZE = 25

    def get_filtered_results(query: nil, user_filter: { scope: 'backend' })
      @stored_filter ||= DataCycleCore::StoredFilter.new
      @filters = pre_filters.dup
      @stored_filter.parameters ||= @filters || []
      @stored_filter.parameters&.reject! { |f| f['v'].is_a?(Hash) ? f['v'].all? { |_, v| v.blank? } : f['v'].blank? }
      query = query&.dup
      @language ||= Array(params.fetch(:language) { @stored_filter.language || [current_user.default_locale] })
      @stored_filter.language = @language

      @sort_params = sort_params.dup
      @stored_filter.sort_parameters ||= (@sort_params.presence || DataCycleCore::StoredFilter.sort_params_from_filter(@stored_filter.parameters.find { |f| f['t'] == 'fulltext_search' }&.dig('v'), @stored_filter.parameters.find { |f| f['t'] == 'in_schedule' }))
      @sort_params = @stored_filter.sort_parameters

      @stored_filter.parameters = current_user.default_filter(@stored_filter.parameters, user_filter) if user_filter.present?
      query = @stored_filter.apply(query: query)

      # used on dashboard
      @filters = @stored_filter.parameters.select { |f| f.key?('c') }.each { |f| f['identifier'] = SecureRandom.hex(10) }
      @selected_classification_aliases = DataCycleCore::ClassificationAlias
        .where(
          id: @filters
            .select { |f|
              f['t'] == 'classification_alias_ids' ||
              (f['t'] == 'geo_filter' && f['q'] == 'geo_within_classification') ||
              (f['t'] == 'advanced_attributes' && f['q'] == 'classification_alias_ids')
            }
            .map { |f| f['v'] }
            .flatten
            .compact
            .uniq
        )
        .includes(:classification_alias_path)
        .index_by(&:id)

      query
    end

    def apply_filter(filter_id:, api_only: false)
      @stored_filter = DataCycleCore::StoredFilter.find(filter_id)
      raise ActiveRecord::RecordNotFound if api_only && !@stored_filter.api

      @stored_filter.update_column(:updated_at, Time.zone.now)
    end

    def save_filter(new_filter: nil)
      new_filter ||= @stored_filter
      new_filter.user_id ||= current_user.id
      new_filter.name = filter_params[:name] if params[:stored_filter].present? && filter_params[:name].present? && !new_filter.persisted?
      new_filter.system = filter_params[:system] if params[:stored_filter].present? && filter_params[:system].present?
      new_filter.parameters = @stored_filter.parameters
      new_filter.language = Array(params.fetch(:language) { @stored_filter.language || [current_user.default_locale] })
      new_filter.sort_parameters = @stored_filter.sort_parameters
      new_filter.save
      new_filter
    end

    def pre_filters
      @pre_filters ||= params[:f].presence&.values&.reject { |f| f['v'].is_a?(Hash) ? f['v'].all? { |_, v| v.blank? } : f['v'].blank? } || []
    end

    def sort_params
      @sort_params ||= params[:s].presence&.values&.reject { |s| s.is_a?(Hash) ? s.any? { |_, v| v.blank? } : s.blank? } || []
    end

    def set_instance_variables_by_view_mode(query: nil, user_filter: { scope: 'backend' })
      set_view_mode

      return @total_count = total_count(query: query, user_filter: user_filter) if count_only_params[:count_only].present?

      case @mode
      when 'tree'
        @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find(mode_params[:ctl_id])

        if mode_params[:con_id].present? && request.xhr?
          @classification_parent_tree = DataCycleCore::ClassificationTree.find(mode_params[:cpt_id])
          @container = DataCycleCore::Thing.find(mode_params[:con_id])
          # TODO: check if ordering is required
          # @order_string = 'things.boost DESC, things.template_name ASC, things.updated_at DESC'
          @contents = get_filtered_results(query: query, user_filter: user_filter)
            .part_of(@container.id)
          tmp_count = @contents.count
          @contents = @contents.content_includes.page(params[:page])

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

          # TODO: check if ordering is required
          # @order_string = 'things.boost DESC, things.template_name ASC, things.updated_at DESC'
          @contents = get_filtered_results(query: query, user_filter: user_filter)
            .classification_alias_ids_without_subtree(@classification_tree.sub_classification_alias.id)
          tmp_count = @contents.count
          @contents = @contents.content_includes.page(params[:page])

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
          get_filtered_results(query: query, user_filter: user_filter) # set default parameters for filters
        end

        @tree_page = @classification_trees&.current_page
        @tree_total_pages = @classification_trees&.total_pages
      else
        page_size = DataCycleCore.main_config.dig(:ui, :dashboard, :page, :size)&.to_i || DEFAULT_PAGE_SIZE
        @contents = get_filtered_results(query: query, user_filter: user_filter)
        @contents = @contents.content_includes.page(params[:page]).per(page_size).without_count
      end
    end

    private

    def apply_ordering(query)
      apply_order_query(query, permitted_params.dig(:sort), @full_text_search, raw_query_params: permitted_params.to_h)
    end

    def build_search_query
      endpoint_id = permitted_params[:id]
      @linked_stored_filter = nil
      if endpoint_id.present?
        @stored_filter = DataCycleCore::StoredFilter.find_by(id: endpoint_id)

        if @stored_filter
          authorize! :api, @stored_filter
          @linked_stored_filter = @stored_filter.linked_stored_filter if @stored_filter.linked_stored_filter_id.present?
          @classification_trees_parameters |= Array.wrap(@stored_filter.classification_tree_labels)
          @classification_trees_filter = @classification_trees_parameters.present?
        elsif (@watch_list = DataCycleCore::WatchList.without_my_selection.find_by(id: endpoint_id))
        else
          raise ActiveRecord::RecordNotFound
        end
      end

      filter = @stored_filter || DataCycleCore::StoredFilter.new
      filter.language = @language
      filter.parameters = current_user.default_filter(filter.parameters, { scope: 'api' })

      query = filter.apply(skip_ordering: order_params_present?(permitted_params))

      query = query.watch_list_id(endpoint_id) unless @watch_list.nil?

      query = query.fulltext_search(@full_text_search) if @full_text_search

      query = query.in_validity_period
      query = apply_filters(query, permitted_params&.dig(:filter))
      query = append_filters(query, permitted_params)
      query
    end

    def set_view_mode
      if mode_params[:mode].in?(['list', 'tree'])
        @mode = mode_params[:mode].to_s
      else
        @mode = 'grid'
      end
    end

    def total_count(query: nil, user_filter: { scope: 'backend' })
      @count_only = true
      @target = count_only_params[:target]
      classification_tree = DataCycleCore::ClassificationTree.find(mode_params[:ct_id]) if mode_params[:ct_id].present?
      total_count = get_filtered_results(query: query, user_filter: user_filter)
      @count_mode = count_only_params[:count_mode]
      @content_class = count_only_params[:content_class]

      case @count_mode
      when 'container'
        total_count = total_count.part_of(mode_params[:con_id])
      when 'classification_alias'
        total_count = total_count.classification_alias_ids_without_subtree(classification_tree.sub_classification_alias.id)
      when 'ca_recursive'
        total_count = total_count.classification_alias_ids_with_subtree(classification_tree.sub_classification_alias.id)
      when 'classification_tree_label'
        ca_label = DataCycleCore::ClassificationTreeLabel.find(mode_params[:ctl_id])
        total_count = total_count.classification_tree_ids(ca_label.id)
      end
      total_count.count
    end

    def load_stored_filter
      apply_filter(filter_id: params[:stored_filter])
    end

    def load_last_filter
      apply_filter(filter_id: current_user.stored_filters.order(updated_at: :desc)&.first&.id)
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
