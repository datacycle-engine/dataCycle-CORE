# frozen_string_literal: true

module DataCycleCore
  class DownloadsController < ApplicationController
    include DataCycleCore::Filter
    include DataCycleCore::ErrorHandler
    include DataCycleCore::DownloadHandler if DataCycleCore::Feature::Download.enabled?

    before_action :authenticate

    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    def things
      @object = DataCycleCore::Thing.find_by(id: params[:id])
      download_single(@object)
    end

    def watch_lists
      @watch_list = DataCycleCore::WatchList.find(params[:id])

      download_items = @watch_list.things.all.to_a.select do |thing|
        DataCycleCore::Feature::Download.allowed?(thing)
      end

      download_zip(@watch_list, download_items)
    end

    def stored_filters
      @stored_filter = DataCycleCore::StoredFilter.find(params[:id])
      raise ActiveRecord::RecordNotFound if !(@stored_filter.api_users + [@stored_filter.user_id]).include?(current_user.id) && !current_user.has_rank?(99)
      items = @stored_filter.apply

      download_items = items.to_a.select do |thing|
        DataCycleCore::Feature::Download.allowed?(thing)
      end

      download_zip(@stored_filter, download_items)
    end

    # def current_ability
    #   DataCycleCore::Ability.new(current_user, session)
    # end

    private

    def authenticate
      return if current_user

      user = User.find_by(access_token: params[:token]) if params[:token].present?
      if user
        sign_in user, store: false
        return
      end

      temp_token = Rails.cache.exist?("download_#{params[:download_token]}") if params[:download_token].present?
      if temp_token
        DataCycleCore::Download.remove_token(key: "download_#{params[:download_token]}")
        return
      end

      raise CanCan::AccessDenied, 'invalid or missing authentication token' unless user
    end
  end
end
