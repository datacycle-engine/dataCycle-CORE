# frozen_string_literal: true

module DataCycleCore
  class StoredFiltersController < ApplicationController
    include DataCycleCore::Filter
    include DataCycleCore::DownloadHandler if DataCycleCore::Feature::Download.enabled?
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource except: [:search, :add_to_watchlist] # from cancancan (authorize)
    before_action :set_default_filter, only: [:create, :add_to_watchlist], if: proc {
      DataCycleCore::Feature::LifeCycle.enabled? &&
        DataCycleCore::Feature::LifeCycle.default_filter.present?
    }

    def index
      @saved_stored_searches = @accessible_stored_filters.where.not(name: nil).order(:name)
      @saved_count = @saved_stored_searches.size

      @stored_searches = current_user.stored_filters.order(updated_at: :desc).page(params[:page])
      @history_count = @stored_searches.total_count
      @pages = @stored_searches.total_pages
      @stored_searches = @stored_searches.group_by { |c| l(c.updated_at&.to_date, format: :long, locale: DataCycleCore.ui_language) }

      respond_to(:html, :js)
    end

    def update
      if @stored_filter.update(stored_filter_params)
        redirect_back(fallback_location: root_path, notice: (I18n.t :created, scope: [:controllers, :success], data: 'Filter', locale: DataCycleCore.ui_language))
      else
        redirect_back(fallback_location: root_path, alert: (I18n.t :not_saved, scope: [:controllers, :errors], data: 'Filter', locale: DataCycleCore.ui_language))
      end
    end

    def create
      @contents = get_filtered_results.distinct_by_content_id(@order_string).content_includes.page(params[:page])

      if stored_filter_params[:id].present?
        @stored_filter = save_filter(new_filter: DataCycleCore::StoredFilter.find(stored_filter_params[:id]))
        redirect_to(root_path(stored_filter: @stored_filter), notice: (I18n.t :updated, scope: [:controllers, :success], data: 'Filter', locale: DataCycleCore.ui_language))
      else
        @stored_filter = save_filter
        redirect_to(root_path(stored_filter: @stored_filter), notice: (I18n.t :created, scope: [:controllers, :success], data: 'Filter', locale: DataCycleCore.ui_language))
      end
    end

    def destroy
      if @stored_filter.update(name: nil)
        redirect_back(fallback_location: root_path, notice: (I18n.t :destroyed, scope: [:controllers, :success], data: 'Filter', locale: DataCycleCore.ui_language))
      else
        redirect_back(fallback_location: root_path, alert: (I18n.t :not_deleted, scope: [:controllers, :errors], data: 'Filter', locale: DataCycleCore.ui_language))
      end
    end

    def search
      authorize! :show, :stored_filter

      stored_filters = DataCycleCore::StoredFilter.where('user_id = ? AND name ILIKE ?', current_user.id, "%#{params[:q]}%").limit(20)

      render json: stored_filters
    end

    def add_to_watchlist
      @stored_filter = DataCycleCore::WatchList.find(params[:watch_list_id])
      authorize! :add_item, @watch_list

      @contents = get_filtered_results.distinct_by_content_id(@order_string)
      @watch_list.thing_ids += @contents.map(&:id)

      redirect_to(root_path, notice: (I18n.t :updated, scope: [:controllers, :success], data: @watch_list.name, locale: DataCycleCore.ui_language))
    end

    def download
      @stored_filter = DataCycleCore::StoredFilter.find(params[:id])
      serialize_format = params[:serialize_format]
      authorize! :download, @stored_filter
      download_stored_filter(@stored_filter, serialize_format)
    end

    def download_zip
      @stored_filter = DataCycleCore::StoredFilter.find(params[:id])
      authorize! :download_zip, @stored_filter
      serialize_format = params.dig(:serialize_format)&.select { |_, v| v.to_i.positive? }&.keys

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.valid_collection_format?('watch_list', serialize_format)

      items = @stored_filter.apply
      download_items = items.to_a.select do |thing|
        can? :download, thing
      end

      download_collection(@stored_filter, download_items, serialize_format)
    end

    private

    def create_params
    end

    def stored_filter_params
      params.require(:stored_filter).permit(:id, :name, :system, :api, api_users: [])
    end
  end
end
