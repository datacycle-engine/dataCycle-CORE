# frozen_string_literal: true

module DataCycleCore
  class StoredFiltersController < ApplicationController
    include DataCycleCore::Filter
    include DataCycleCore::DownloadHandler if DataCycleCore::Feature::Download.enabled?
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource except: [:search, :add_to_watchlist] # from cancancan (authorize)

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
      @contents = get_filtered_results(user_filter: nil)

      @stored_filter = save_filter(new_filter: stored_filter_params[:id] ? DataCycleCore::StoredFilter.find(stored_filter_params[:id]) : nil)

      redirect_to(root_path(stored_filter: @stored_filter), notice: (I18n.t (stored_filter_params[:id].present? ? :updated : :created), scope: [:controllers, :success], data: 'Filter', locale: DataCycleCore.ui_language))
    end

    def destroy
      @stored_filter.filter_uses.update_all(linked_stored_filter_id: nil) # rubocop:disable Rails/SkipsModelValidations
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
      redirect_to(root_path, alert: (I18n.t :no_watchlist, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if params[:watch_list_id].blank?

      @watch_list = DataCycleCore::WatchList.find_by(id: params[:watch_list_id])
      @watch_list = current_user.watch_lists.create(full_path: params[:watch_list_id]) if @watch_list.nil?

      authorize! :add_item, @watch_list

      content_query = get_filtered_results.select("'#{@watch_list.id}', things.id, 'DataCycleCore::Thing', NOW(), NOW()")

      ActiveRecord::Base.connection.execute <<-SQL.squish
        INSERT INTO watch_list_data_hashes (watch_list_id, hashable_id, hashable_type, created_at, updated_at)
        #{content_query.to_sql}
        ON CONFLICT DO NOTHING
      SQL

      redirect_to(root_path, notice: (I18n.t :added_to, scope: [:controllers, :success], data: @watch_list.name, locale: DataCycleCore.ui_language))
    end

    def download
      @stored_filter = DataCycleCore::StoredFilter.find(params[:id])
      serialize_format = params[:serialize_format]
      languages = params[:language]
      authorize! :download, @stored_filter
      download_stored_filter(@stored_filter, serialize_format, languages)
    end

    def download_zip
      @stored_filter = DataCycleCore::StoredFilter.find(params[:id])
      authorize! :download_zip, @stored_filter
      serialize_format = params.dig(:serialize_format)&.select { |_, v| v.to_i.positive? }&.keys
      languages = params[:language]

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.valid_collection_format?('stored_filter', serialize_format)

      items = @stored_filter.apply
      download_items = items.to_a.select do |thing|
        can? :download, thing
      end

      download_collection(@stored_filter, download_items, serialize_format, languages)
    end

    private

    def create_params
    end

    def stored_filter_params
      params.require(:stored_filter).permit(:id, :name, :system, :api, :linked_stored_filter_id, api_users: [])
    end
  end
end
