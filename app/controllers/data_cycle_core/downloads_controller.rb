# frozen_string_literal: true

module DataCycleCore
  class DownloadsController < ApplicationController
    include DataCycleCore::Filter
    include DataCycleCore::DownloadHandler if DataCycleCore::Feature::Download.enabled?

    before_action :authenticate_user! # from devise (authenticate)
    after_action :reset_watch_list, only: :watch_list_collections, if: -> { params[:reset].present? }

    def things
      @object = DataCycleCore::Thing.find_by(id: permitted_download_params[:id])
      serialize_format = permitted_download_params[:serialize_format] || 'asset'
      version = permitted_download_params[:version]
      languages = permitted_download_params[:language]
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.allowed?(@object, :content) && DataCycleCore::Feature::Download.enabled_serializer_for_download?(@object, :content, serialize_format)
      download_content(@object, serialize_format, [languages], version)
    end

    def watch_lists
      @watch_list = DataCycleCore::WatchList.find(permitted_download_params[:id])
      serialize_format = permitted_download_params[:serialize_format]
      languages = permitted_download_params[:language]
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.allowed?(@watch_list, :content) && DataCycleCore::Feature::Download.enabled_serializer_for_download?(@watch_list, :content, serialize_format)
      download_content(@watch_list, serialize_format, [languages])
    end

    def stored_filters
      @stored_filter = DataCycleCore::StoredFilter.find(permitted_download_params[:id])
      serialize_format = permitted_download_params[:serialize_format]
      languages = permitted_download_params[:language]
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.allowed?(@stored_filter, :content) && DataCycleCore::Feature::Download.enabled_serializer_for_download?(@stored_filter, :content, serialize_format)
      download_content(@stored_filter, serialize_format, [languages])
    end

    def thing_collections
      @object = DataCycleCore::Thing.find(permitted_download_params[:id])
      serialize_formats = permitted_download_params[:serialize_format]&.split(',')&.map(&:strip)
      languages = permitted_download_params[:language]&.split(',')

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@object, [:archive, :zip], serialize_formats)

      download_items = ([@object] + @object.content_b_linked).to_a.select do |thing|
        DataCycleCore::Feature::Download.allowed?(thing)
      end
      download_collection(@object, download_items, serialize_formats, languages)
    end

    def watch_list_collections
      @watch_list = DataCycleCore::WatchList.find(permitted_download_params[:id])
      serialize_formats = permitted_download_params[:serialize_format]&.split(',')&.map(&:strip) || ['asset']
      languages = permitted_download_params[:language]&.split(',')
      versions = params.permit(versions: {}).dig(:versions)&.to_h

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@watch_list, [:archive, :zip], serialize_formats)

      download_items = @watch_list.things.all.to_a.select do |thing|
        DataCycleCore::Feature::Download.allowed?(thing)
      end

      download_collection(@watch_list, download_items, serialize_formats, languages, versions)
    end

    def stored_filter_collections
      @stored_filter = DataCycleCore::StoredFilter.find(permitted_download_params[:id])
      serialize_formats = permitted_download_params[:serialize_format]&.split(',')&.map(&:strip) || ['asset']
      languages = permitted_download_params[:language]&.split(',')

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@stored_filter, [:archive, :zip], serialize_formats)

      items = @stored_filter.apply
      download_items = items.to_a.select do |thing|
        DataCycleCore::Feature::Download.allowed?(thing)
      end

      download_collection(@stored_filter, download_items, serialize_formats, languages)
    end

    private

    def reset_watch_list
      @watch_list.watch_list_data_hashes.delete_all
    end

    def permitted_download_params
      params.permit(:id, :serialize_format, :version, :language)
    end
  end
end
