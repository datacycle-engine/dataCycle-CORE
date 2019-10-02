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
      serialize_format = params[:serialize_format] || 'asset'
      version = params[:version]
      languages = params[:language]
      download_content(@object, serialize_format, [languages], version)
    end

    def watch_lists
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      serialize_format = params[:serialize_format]
      languages = params[:language]
      download_watch_list(@watch_list, serialize_format, [languages])
    end

    def stored_filters
      @stored_filter = DataCycleCore::StoredFilter.find(params[:id])
      serialize_format = params[:serialize_format]
      languages = params[:language]
      download_stored_filter(@stored_filter, serialize_format, [languages])
    end

    def thing_collections
      @object = DataCycleCore::Thing.find(params[:id])
      serialize_format = params[:serialize_format]&.split(',')
      languages = params[:language]&.split(',')

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.valid_collection_format?('content', serialize_format)

      download_items = ([@object] + @object.content_b_linked).to_a.select do |thing|
        can? :download, thing
      end

      download_collection(@object, download_items, serialize_format, languages)
    end

    def watch_list_collections
      @watch_list = DataCycleCore::WatchList.find(params[:id])
      serialize_format = params[:serialize_format]&.split(',') || ['asset']
      languages = params[:language]&.split(',')
      versions = params.permit(versions: {}).dig(:versions)&.to_h

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.valid_collection_format?('watch_list', serialize_format)

      download_items = @watch_list.things.all.to_a.select do |thing|
        DataCycleCore::Feature::Download.allowed?(thing)
      end

      download_collection(@watch_list, download_items, serialize_format, languages, versions)
    end

    def stored_filter_collections
      @stored_filter = DataCycleCore::StoredFilter.find(params[:id])
      serialize_format = params[:serialize_format]&.split(',') || ['asset']
      languages = params[:language]&.split(',')

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.valid_collection_format?('stored_filter', serialize_format)

      items = @stored_filter.apply
      download_items = items.to_a.select do |thing|
        DataCycleCore::Feature::Download.allowed?(thing)
      end

      download_collection(@stored_filter, download_items, serialize_format, languages)
    end

    private

    def authenticate
      return if current_user

      if params[:jwt_token].present?
        begin
          @decoded = DataCycleCore::JsonWebToken.decode(params[:jwt_token])
          @user = DataCycleCore::User.find_with_token(@decoded)
        rescue JWT::DecodeError, JSON::ParserError => e
          raise CanCan::AccessDenied, e.message
        end
      elsif params[:token].present?
        @user = User.find_by(access_token: params[:token])
      elsif params[:download_token].present? && Rails.cache.exist?("download_#{params[:download_token]}")
        @user = User.find(Rails.cache.read("download_#{params[:download_token]}"))
        DataCycleCore::Download.remove_token(key: "download_#{params[:download_token]}")
      end

      raise CanCan::AccessDenied, 'invalid or missing authentication token' if @user.nil?

      sign_in @user, store: false
      @current_user = @user
    end
  end
end
