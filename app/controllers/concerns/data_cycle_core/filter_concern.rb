# frozen_string_literal: true

module DataCycleCore
  module FilterConcern
    extend ActiveSupport::Concern

    DEFAULT_PAGE_SIZE = 25
    # Sentinel used in place of a concept scheme id (`ctl_id`) to render the
    # dashboard tree view grouped by external system instead of by concept.
    EXTERNAL_SYSTEM_TREE_ID = 'external_systems'
    PAGE_PARAMS_SCHEMA = DataCycleCore::BaseSchema.params do
      optional(:page).filled(:integer)
      optional(:tree_page).filled(:integer)
    end
    SORT_PARAMS_SCHEMA = DataCycleCore::BaseSchema.params do
      optional(:s).hash do
        optional(:v).hash do
          optional(:o).filled(:string, included_in?: ['DESC', 'ASC'])
          optional(:m).maybe(:string)
        end
      end
    end

    def get_filtered_results(query: nil, user_filter: { scope: 'backend' }, watch_list: nil)
      @stored_filter ||= DataCycleCore::StoredFilter.new
      @filters = pre_filters.reject { |f| DataCycleCore::DataHashService.blank?(f['v']) }
      @stored_filter.apply_sorting_from_parameters(sort_params: sort_params.dup, filters: @filters)
      @stored_filter.parameters ||= @filters || []
      @language ||= Array(params.fetch(:language) { @stored_filter.language || [current_user.default_locale] })
      @stored_filter.language = @language
      @sort_params = @stored_filter.sort_parameters
      @stored_filter.apply_user_filter(current_user, user_filter, filter_reset?(@stored_filter)) if user_filter.present?
      query = @stored_filter.apply(query: query&.dup, skip_ordering: @count_only, watch_list:)

      # dashboard chips: user filters live outside `parameters`, so include them via
      # #parameters_with_user_filters to keep the user/forced filter chips visible.
      @filters = @stored_filter.parameters_with_user_filters.select { |f| f.key?('c') }.each { |f| f['identifier'] = SecureRandom.hex(10) }
      @selected_concepts = selected_concepts_by_id(@filters)

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
      # persist only the form-derived parameters, never the user filters: those are resolved per viewer at
      # read time (see StoredFilter#user_filter_parameters), so a filter saved by a restricted user must not
      # carry that restriction for everyone who later opens it.
      new_filter.parameters = @stored_filter.parameters
      new_filter.language = Array(params.fetch(:language) { @stored_filter.language || [current_user.default_locale] })
      new_filter.sort_parameters = @stored_filter.sort_parameters
      new_filter.save
      new_filter
    end

    def pre_filters
      # @pre_filters is used to override pre_filters
      @pre_filters ||= params
        .to_unsafe_hash[:f]
        .presence
        &.values
        &.reject { |f| DataCycleCore::StoredFilter.narrows_nothing?(f) } || []
    end

    def sort_params
      # @sort_params is used to override sort_params
      @sort_params ||= Array.wrap(params_for(SORT_PARAMS_SCHEMA).dig(:s, :v)&.compact_blank.presence)
    end

    def set_instance_variables_by_view_mode(query: nil, user_filter: { scope: 'backend' }, watch_list: nil)
      set_view_mode

      return @total_count = total_count(query:, user_filter:) if count_only_params[:count_only].present?

      case @mode
      when 'tree'
        return set_external_system_tree_variables(query:, user_filter:) if mode_params[:ctl_id] == EXTERNAL_SYSTEM_TREE_ID

        @concept_scheme = DataCycleCore::ConceptScheme.find_by(id: mode_params[:ctl_id])

        # unresolvable tree context (e.g. a stale/blank ctl_id): fall back to the grid view
        if @concept_scheme.nil?
          @mode = 'grid'
          return set_grid_variables(query:, user_filter:, watch_list:)
        end

        if mode_params[:con_id].present? && request.xhr?
          @parent_concept = DataCycleCore::Concept.find(mode_params[:cpt_id])
          @container = DataCycleCore::Thing.find(mode_params[:con_id])
          @contents = get_filtered_results(query:, user_filter:)
            .part_of(@container.id)
          tmp_count = @contents.count
          @contents = @contents.content_includes.page(page_params[:page])
          DataCycleCore::PreloadService.preload(@contents, :watch_lists, DataCycleCore::WatchList.accessible_by(current_ability).preload(:collection_shares))

          @page = @contents.current_page
          @total_count = @contents.instance_variable_set(:@total_count, tmp_count)
          @total_pages = @contents.total_pages
        elsif mode_params[:ct_id].present?
          @concept = DataCycleCore::Concept.find(mode_params[:ct_id])
          @concepts = tree_concepts(@concept.children)

          filtered_results = get_filtered_results(query:, user_filter:)

          @contents = filtered_results.concept_ids_without_subtree(@concept.id)
          @contents_related = filtered_results.concept_ids_related(@concept.id)

          total_count = @contents.count
          total_count_related = @contents_related.count

          @contents = @contents.content_includes.page(page_params[:page])
          @contents = @contents.tap { |rel| rel.send(:load_records, []) } if total_count.zero?
          PreloadService.preload(@contents, :watch_lists, DataCycleCore::WatchList.accessible_by(current_ability).preload(:collection_shares))

          @contents_related = @contents_related.content_includes.page(page_params[:page])
          @contents_related = @contents_related.tap { |rel| rel.send(:load_records, []) } if total_count_related.zero?
          PreloadService.preload(@contents_related, :watch_lists, DataCycleCore::WatchList.accessible_by(current_ability).preload(:collection_shares))

          @page_related = @contents_related.current_page
          @total_count_related = @contents_related.instance_variable_set(:@total_count, total_count_related)
          @total_pages_related = @contents_related.total_pages

          @page = @contents.current_page
          @total_count = @contents.instance_variable_set(:@total_count, total_count)
          @total_pages = @contents.total_pages
        else
          @concepts = tree_concepts(@concept_scheme.concepts.roots)
          get_filtered_results(query:, user_filter:) # set default parameters for filters
        end

        @tree_page = @concepts&.current_page
        @tree_total_pages = @concepts&.total_pages
      when 'map'
        page_size = DataCycleCore.main_config.dig(:ui, :dashboard, :page, :size)&.to_i || DEFAULT_PAGE_SIZE
        @contents = get_filtered_results(query:, user_filter:, watch_list:)
          .page(page_params[:page])
          .per(page_size)
          .without_count
      else
        set_grid_variables(query:, user_filter:, watch_list:)
      end
    end

    private

    # The concepts a filter chip has to name, indexed by id: the chip prints a concept, while the
    # filter holds ids in its `v`. PublicationsController renders the same chips and had grown its own
    # copy of this, which then drifted - it asked for `t == 'geo_within_classification'`, a `t` no
    # filter carries (the `t` is `geo_filter`, and only its advanced type in `q` says which geo filter
    # it is), so a radius-filtered publications dashboard printed bare ids.
    #
    # @param filters [Array<Hash>] stored filter parameters, each with the `t`/`q`/`v` keys
    # @return [Hash{String => DataCycleCore::Concept}]
    def selected_concepts_by_id(filters)
      DataCycleCore::Concept
        .where(id: filters.select { |f| concept_ids_in_filter_value?(f) }.pluck('v').flatten.compact.uniq)
        .includes(:concept_path)
        .index_by(&:id)
    end

    # One page of dashboard tree nodes. `Inhaltstypen` hides the content types that are excluded
    # from filtering everywhere else (see DataCycleCore.excluded_filter_classifications).
    def tree_concepts(concepts)
      concepts = concepts.where.not(internal_name: DataCycleCore.excluded_filter_classifications) if @concept_scheme.name == 'Inhaltstypen'

      concepts
        .includes(:concept_path, :external_system, children: :concept_path)
        .page(page_params[:tree_page])
    end

    def concept_ids_in_filter_value?(filter)
      filter['t'] == 'concept_ids' ||
        (filter['t'] == 'geo_filter' && filter['q'] == 'geo_within_classification') ||
        (filter['t'] == 'advanced_attributes' && filter['q'] == 'concept_ids')
    end

    # Builds the dashboard tree view grouped by external system (the "imported from" breakdown):
    # lists the active import external systems as tree nodes. Each node's content count is loaded
    # lazily via the `external_system` count mode (see #total_count). Clicking a node expands the
    # contents imported from that system (loaded via xhr, see #set_external_system_contents).
    def set_external_system_tree_variables(query:, user_filter:)
      @external_system_tree = true
      @external_system = DataCycleCore::ExternalSystem.find_by(id: mode_params[:es_id]) if mode_params[:es_id].present?

      # an xhr request for a selected system is a drill-in (or load-more) that renders only the
      # contents fragment; the full html page always renders the external-system node list
      return set_external_system_contents(query:, user_filter:) if @external_system && request.xhr?

      @external_systems = DataCycleCore::ExternalSystem.with_import_config.where(deactivated: false).order(:name)
      get_filtered_results(query:, user_filter:) # set default parameters for filters
    end

    # Paged list of contents imported from a single external system (its primary source).
    def set_external_system_contents(query:, user_filter:)
      contents = get_filtered_results(query:, user_filter:).external_source([@external_system.id])
      total_count = contents.count

      @contents = contents.content_includes.page(page_params[:page])
      @contents = @contents.tap { |rel| rel.send(:load_records, []) } if total_count.zero?
      DataCycleCore::PreloadService.preload(@contents, :watch_lists, DataCycleCore::WatchList.accessible_by(current_ability).preload(:collection_shares))

      @page = @contents.current_page
      @total_count = @contents.instance_variable_set(:@total_count, total_count)
      @total_pages = @contents.total_pages
    end

    def set_grid_variables(query:, user_filter:, watch_list: nil)
      page_size = DataCycleCore.main_config.dig(:ui, :dashboard, :page, :size)&.to_i || DEFAULT_PAGE_SIZE
      @contents = get_filtered_results(query:, user_filter:, watch_list:)
      @contents = @contents.content_includes.page(page_params[:page]).per(page_size).without_count
      DataCycleCore::PreloadService.preload(@contents, :watch_lists, DataCycleCore::WatchList.accessible_by(current_ability).preload(:collection_shares))
    end

    def linked_stored_filter(collection = nil)
      user_linked_filters = current_user&.user_filters('api_linked')

      return unless collection&.linked_stored_filter_id.present? || user_linked_filters.present?

      linked_filter = collection&.linked_stored_filter

      return linked_filter if user_linked_filters.blank?

      unique_key = DataCycleCore::UuidService.generate(collection&.id || @content&.id, "#{user_linked_filters.join(',')}/#{current_user.id}")
      linked_filter ||= DataCycleCore::StoredFilter.new(id: unique_key)
      linked_filter.apply_user_filter(current_user, { scope: 'api_linked' })
    end

    # used only in APIv4 and sync_api
    def build_search_query
      endpoint_id = permitted_params[:id]
      @linked_stored_filter = nil

      if endpoint_id.present?
        @collection = DataCycleCore::Collection.by_id_or_slug(endpoint_id).first!

        authorize! :api, @collection unless self.class.module_parents.include?(DataCycleCore::Mvt) && any_authenticity_token_valid?

        @stored_filter = @collection if @collection.is_a?(DataCycleCore::StoredFilter)
        @watch_list = @collection if @collection.is_a?(DataCycleCore::WatchList)
        @linked_stored_filter = linked_stored_filter(@collection)
        @classification_trees_parameters |= Array.wrap(@collection.concept_scheme_ids)
        @classification_trees_filter = @classification_trees_parameters.present?
      end

      filter = @stored_filter || DataCycleCore::StoredFilter.new
      filter.language = @language
      filter.apply_user_filter(current_user, { scope: 'api' })
      filter.apply_sorting_from_api_parameters(permitted_params.to_h)

      query = filter.cached.apply(watch_list: @watch_list)
      query = query.watch_list_id(@watch_list.id) unless @watch_list.nil?

      query = apply_filters(query, permitted_params&.dig(:filter))
      append_filters(query, permitted_params)
    end

    def set_view_mode
      @mode = if mode_params[:mode].in?(['list', 'tree', 'map'])
                mode_params[:mode].to_s
              else
                'grid'
              end
    end

    def total_count(query: nil, user_filter: { scope: 'backend' })
      @count_only = true
      @target = count_only_params[:target]
      concept = DataCycleCore::Concept.find(mode_params[:ct_id]) if mode_params[:ct_id].present?
      total_count = get_filtered_results(query:, user_filter:)
      total_count = total_count.with_geometry if @mode == 'map'
      @count_mode = count_only_params[:count_mode]
      @content_class = count_only_params[:content_class]

      case @count_mode
      when 'container'
        total_count = total_count.part_of(mode_params[:con_id])
      when 'concept'
        total_count = total_count.concept_ids_without_subtree(concept.id)
      when 'concept_related'
        total_count = total_count.concept_ids_without_subtree_with_related(concept.id)
      when 'concept_recursive'
        total_count = total_count.concept_ids_with_subtree(concept.id)
      when 'concept_scheme'
        total_count = total_count.concept_scheme_ids(mode_params[:ctl_id])
      when 'external_system'
        total_count = total_count.external_source([mode_params[:es_id]])
      end

      total_count.count
    end

    def load_stored_filter
      apply_filter(filter_id: params[:stored_filter])
    end

    def load_last_filter
      last_id = current_user.stored_filters.order(updated_at: :desc)&.pick(:id)

      apply_filter(filter_id: last_id) if last_id.present?
    end

    def filter_params
      params.expect(stored_filter: [:id, :name])
    end

    def mode_params
      params.permit(:mode, :ct_id, :con_id, :ctl_id, :cpt_id, :es_id)
    end

    def count_only_params
      params.permit(:target, :count_only, :count_mode, :content_class)
    end

    def load_previous_page?
      request.format.html? &&
        params.slice(:stored_filter, :f, :reset).blank? &&
        session[:return_to].present? &&
        request.path == Addressable::URI.parse(session[:return_to].to_s).path
    end

    def load_previous_page
      redirect_to(session.delete(:return_to)) && return
    end

    def filter_reset?(stored_filter)
      params.permit(:reset)[:reset].present? || (!stored_filter.persisted? && params.slice(:stored_filter, :f).blank?)
    end

    def page_params
      params_for(PAGE_PARAMS_SCHEMA)
    end
  end
end
