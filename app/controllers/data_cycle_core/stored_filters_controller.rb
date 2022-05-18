# frozen_string_literal: true

module DataCycleCore
  class StoredFiltersController < ApplicationController
    include DataCycleCore::Filter
    include DataCycleCore::DownloadHandler if DataCycleCore::Feature::Download.enabled?
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource except: [:search, :select_search_or_collection, :add_to_watchlist] # from cancancan (authorize)

    def index
      @saved_stored_searches = @accessible_stored_filters.where.not(name: nil).order(:name)
      @saved_count = @saved_stored_searches.size

      @stored_searches = current_user.stored_filters.order(updated_at: :desc).page(params[:page])
      @history_count = @stored_searches.total_count
      @pages = @stored_searches.total_pages
      @stored_searches = @stored_searches.group_by { |c| l(c.updated_at&.to_date, format: :long, locale: helpers.active_ui_locale) }

      respond_to(:html, :js)
    end

    def show
      redirect_to root_path(stored_filter: @stored_filter)
    end

    def update
      cleaned_params = stored_filter_params
      cleaned_params[:classification_tree_labels] = stored_filter_params[:classification_tree_labels]&.map(&:presence)&.compact
      if @stored_filter.update(cleaned_params)
        redirect_back(fallback_location: root_path, notice: (I18n.t :created, scope: [:controllers, :success], data: 'Filter', locale: helpers.active_ui_locale))
      else
        redirect_back(fallback_location: root_path, alert: (I18n.t :not_saved, scope: [:controllers, :errors], data: 'Filter', locale: helpers.active_ui_locale))
      end
    end

    def create
      @contents = get_filtered_results(user_filter: nil)

      @stored_filter = save_filter(new_filter: stored_filter_params[:id] ? DataCycleCore::StoredFilter.find(stored_filter_params[:id]) : nil)

      redirect_to(root_path(stored_filter: @stored_filter), notice: (I18n.t (stored_filter_params[:id].present? ? :updated : :created), scope: [:controllers, :success], data: 'Filter', locale: helpers.active_ui_locale))
    end

    def destroy
      @stored_filter.filter_uses.update_all(linked_stored_filter_id: nil)
      if @stored_filter.update(name: nil)
        redirect_back(fallback_location: root_path, notice: (I18n.t :destroyed, scope: [:controllers, :success], data: 'Filter', locale: helpers.active_ui_locale))
      else
        redirect_back(fallback_location: root_path, alert: (I18n.t :not_deleted, scope: [:controllers, :errors], data: 'Filter', locale: helpers.active_ui_locale))
      end
    end

    def search
      authorize! :show, DataCycleCore::StoredFilter

      stored_filters = DataCycleCore::StoredFilter.accessible_by(current_ability, :update)
        .includes(:user)
        .where('name ILIKE ?', "%#{params[:q].gsub(/ \| .*<.*@.*>$/, '')}%")
        .limit(20)

      render json: stored_filters.map { |filter|
        filter.tap { |f| f.name += " | #{f.user.full_name} <#{f.user.email}>" if f.user_id != current_user.id }
      }
    end

    def select_search_or_collection
      authorize! :show, DataCycleCore::StoredFilter

      filter_string = select_search_params[:q]&.strip
      filter_proc = ->(query, query_table) { query.where(query_table[:name].matches("%#{filter_string}%")) } if filter_string.present?
      arel_query = @accessible_stored_filters.combine_with_collections(DataCycleCore::WatchList.accessible_by(current_ability).conditional_my_selection, filter_proc)
      arel_query = arel_query.take(select_search_params[:max].to_i) if select_search_params[:max].present?

      result = ActiveRecord::Base.connection.select_all arel_query.to_sql

      render plain: result.map { |s| DataCycleCore::CollectionService.to_select_option(s, helpers.active_ui_locale) }.to_json, content_type: 'application/json'
    end

    def add_to_watchlist
      redirect_to(root_path, alert: (I18n.t :no_watchlist, scope: [:controllers, :error], locale: helpers.active_ui_locale)) && return if params[:watch_list_id].blank?

      @watch_list = DataCycleCore::WatchList.find_by(id: params[:watch_list_id])
      @watch_list = current_user.watch_lists.create(full_path: params[:watch_list_id]) if @watch_list.nil?

      authorize! :add_item, @watch_list

      content_query = get_filtered_results.select("'#{@watch_list.id}', things.id, 'DataCycleCore::Thing', NOW(), NOW()")

      ActiveRecord::Base.connection.execute <<-SQL.squish
        INSERT INTO watch_list_data_hashes (watch_list_id, hashable_id, hashable_type, created_at, updated_at)
        #{content_query.to_sql}
        ON CONFLICT DO NOTHING
      SQL

      redirect_to(root_path, notice: (I18n.t :added_to, scope: [:controllers, :success], data: @watch_list.name, locale: helpers.active_ui_locale))
    end

    def download
      @stored_filter = DataCycleCore::StoredFilter.find(params[:id])
      serialize_format = params[:serialize_format]
      languages = params[:language]
      authorize! :download, @stored_filter
      download_content(@stored_filter, serialize_format, languages)
    end

    def download_zip
      @stored_filter = DataCycleCore::StoredFilter.find(params[:id])
      authorize! :download_zip, @stored_filter
      serialize_formats = params.dig(:serialize_format)&.select { |_, v| v.to_i.positive? }&.keys
      languages = params[:language]

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@stored_filter, [:archive, :zip], serialize_formats)

      items = @stored_filter.apply
      download_items = items.to_a.select do |thing|
        can? :download, thing
      end

      download_collection(@stored_filter, download_items, serialize_formats, languages)
    end

    private

    def create_params
    end

    def stored_filter_params
      params.require(:stored_filter).permit(:id, :name, :system, :api, :linked_stored_filter_id, classification_tree_labels: [], api_users: [])
    end

    def select_search_params
      params.permit(:q, :max)
    end
  end
end
