# frozen_string_literal: true

module DataCycleCore
  class StoredFiltersController < ApplicationController
    include DataCycleCore::FilterConcern

    load_and_authorize_resource except: [:create, :search, :select_search_or_collection, :add_to_watchlist, :saved_searches, :render_update_form] # from cancancan (authorize)

    def index
      @page = (index_params[:page] || 1).to_i
      @stored_searches = current_user.stored_filters.order(updated_at: :desc).page(@page)
      @history_count = @stored_searches.total_count
      @last_page = @stored_searches.last_page?
      @stored_searches = @stored_searches.group_by { |c| l(c.updated_at&.to_date, format: :long, locale: helpers.active_ui_locale) }

      respond_to do |format|
        format.html
        format.json do
          render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/stored_filters/stored_searches', locals: { stored_searches: @stored_searches, last_page: @last_page, page: @page, last_day: index_params[:last_day] }) }
        end
      end
    end

    def saved_searches
      authorize! :index, DataCycleCore::StoredFilter

      @stored_searches = DataCycleCore::StoredFilter.includes(:linked_stored_filter, :concept_schemes, :shared_users, :shared_user_groups, :shared_roles).accessible_by(current_ability).named.order(:name)
      @search_param = index_params[:q]

      @stored_searches = @stored_searches.by_id_name_slug_description(@search_param) if @search_param.present?

      @page = (index_params[:page] || 1).to_i

      if index_params[:load_all].present?
        @stored_searches = @stored_searches.offset(DEFAULT_PAGE_SIZE * (@page - 1))
        @last_page = true
      else
        @stored_searches = @stored_searches.page(@page).per(DEFAULT_PAGE_SIZE)
        @last_page = @stored_searches.last_page?
      end

      respond_to do |format|
        format.html do
          @saved_count = @stored_searches.total_count
        end
        format.json do
          partial = "data_cycle_core/stored_filters/#{index_params[:partial].presence || 'saved_searches_list'}"

          @stored_searches.reorder(updated_at: :desc) if @search_param.blank?

          json = {
            html: render_to_string(
              formats: [:html],
              layout: false,
              partial:,
              locals: {
                stored_searches: @stored_searches,
                last_page: @last_page,
                page: @page
              }
            )
          }

          if @page == 1
            json[:count] = @stored_searches.total_count
            json[:count_string] = helpers.number_with_delimiter(@stored_searches.total_count.to_i, locale: helpers.active_ui_locale)
          end

          render json:
        end
      end
    end

    def show
      redirect_to root_path(stored_filter: @stored_filter)
    end

    def create
      stored_filter = if stored_filter_params[:id].present?
                        DataCycleCore::StoredFilter.find(stored_filter_params[:id])
                      else
                        DataCycleCore::StoredFilter.new(user_id: current_user.id)
                      end

      authorize! stored_filter.new_record? ? :create : :update, stored_filter

      stored_filter.attributes = stored_filter_params

      if params[:update_filter_parameters]
        get_filtered_results(user_filter: nil) # prefill stored_filter params
        stored_filter = save_filter(new_filter: stored_filter)

        redirect_to(root_path(stored_filter:), notice: (I18n.t (stored_filter_params[:id].present? ? :updated : :created), scope: [:controllers, :success], data: DataCycleCore::StoredFilter.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
      elsif stored_filter.save
        redirect_back(fallback_location: root_path, notice: (I18n.t :updated, scope: [:controllers, :success], data: DataCycleCore::StoredFilter.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
      else
        redirect_back(fallback_location: root_path, alert: (I18n.t :not_saved, scope: [:controllers, :errors], data: DataCycleCore::StoredFilter.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
      end
    end

    def render_update_form
      @stored_filter = stored_filter_params[:id].present? ? DataCycleCore::StoredFilter.find(stored_filter_params[:id]) : DataCycleCore::StoredFilter.new(user_id: current_user&.id)

      authorize! @stored_filter.new_record? ? :create : :update, @stored_filter

      render json: {
        html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/stored_filters/edit_form', locals: { stored_search: @stored_filter, update_params: true })
      }
    end

    def destroy
      @stored_filter.filter_uses.update_all(linked_stored_filter_id: nil)

      if @stored_filter.update(name: nil)
        redirect_back(fallback_location: root_path, notice: (I18n.t :destroyed, scope: [:controllers, :success], data: DataCycleCore::StoredFilter.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
      else
        redirect_back(fallback_location: root_path, alert: (I18n.t :not_deleted, scope: [:controllers, :errors], data: DataCycleCore::StoredFilter.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
      end
    end

    def search
      authorize! :show, DataCycleCore::StoredFilter

      stored_filters = DataCycleCore::StoredFilter.accessible_by(current_ability, :update)
        .includes(:user)
        .limit(20)
        .order(name: :asc)

      stored_filters = stored_filters.where('name ILIKE ?', "%#{index_params[:q]&.strip}%") if index_params[:q].present?

      render plain: stored_filters.map { |filter|
        select_option = filter.to_select_option

        if filter.user_id != current_user.id
          suffix = helpers.tag.span(helpers.safe_join([' |', filter.user_with_deleted.full_name_with_status, "<#{filter.user_with_deleted.email}>"], ' '), class: 'stored-filter-creator')
          select_option.name = helpers.safe_join([select_option.name, suffix])
          select_option.dc_tooltip = helpers.safe_join([select_option.dc_tooltip, suffix])
        end

        select_option
      }.to_json, content_type: 'application/json'
    end

    def select_search_or_collection
      authorize! :show, DataCycleCore::StoredFilter

      filter_string = select_search_params[:q]&.strip

      query = DataCycleCore::Collection.accessible_by_subclass(current_ability).conditional_my_selection.by_id_name_slug_description(filter_string)
      query = query.limit(select_search_params[:max].to_i) if select_search_params[:max].present?

      render plain: query.map { |c| c.to_select_option(helpers.active_ui_locale) }.to_json, content_type: 'application/json'
    end

    def add_to_watchlist
      redirect_to(root_path, alert: (I18n.t :no_watchlist, scope: [:controllers, :error], locale: helpers.active_ui_locale)) && return if params[:watch_list_id].blank?

      @watch_list = DataCycleCore::WatchList.find_by(id: params[:watch_list_id])
      @watch_list = current_user.watch_lists.create(full_path: params[:watch_list_id]) if @watch_list.nil?

      authorize! :add_item, @watch_list

      inserted_ids = @watch_list.add_things_from_query(get_filtered_results)

      @watch_list.notify_subscribers(current_user, inserted_ids, 'add')

      redirect_to(root_path, notice: I18n.t('controllers.success.added_to', data: @watch_list.name, type: DataCycleCore::WatchList.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    private

    def stored_filter_params
      params
        .require(:stored_filter)
        .permit(:id, :name, :api, :user_id, :linked_stored_filter_id, :description, shared_user_ids: [], shared_user_group_ids: [], shared_role_ids: [], classification_tree_labels: [])
        .tap do |p|
          p[:name] ||= p.delete(:id) unless p[:id].to_s.uuid?
          p[:description] = DataCycleCore::MasterData::DataConverter.string_to_string(p[:description]) if p.key?(:description)
        end
    end

    def select_search_params
      params.permit(:q, :max)
    end

    def index_params
      params.permit(:page, :last_day, :q, :load_all, :partial)
    end
  end
end
