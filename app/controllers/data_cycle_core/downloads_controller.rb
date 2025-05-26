# frozen_string_literal: true

module DataCycleCore
  class DownloadsController < ApplicationController
    include DataCycleCore::FilterConcern
    include DataCycleCore::DownloadHandler if DataCycleCore::Feature::Download.enabled?

    after_action :reset_watch_list, only: :watch_list_collections, if: -> { params[:reset].present? }

    def things
      @object = DataCycleCore::Thing.find_by(id: permitted_download_params[:id])
      serialize_format = permitted_download_params[:serialize_format] ||
                         DataCycleCore::Feature::Download
                           .enabled_serializers_for_download(@object, [:content])
                           .keys
                           .first
      version = permitted_download_params[:version]
      languages = permitted_download_params[:language]
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.allowed?(@object, :content) && DataCycleCore::Feature::Download.enabled_serializer_for_download?(@object, :content, serialize_format)
      download_content(@object, serialize_format, Array.wrap(languages), version)
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def watch_lists
      @watch_list = DataCycleCore::WatchList.find(permitted_download_params[:id])
      serialize_format = permitted_download_params[:serialize_format]
      languages = permitted_download_params[:language]
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.allowed?(@watch_list, :content) && DataCycleCore::Feature::Download.enabled_serializer_for_download?(@watch_list, :content, serialize_format)
      download_content(@watch_list, serialize_format, Array.wrap(languages))
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def stored_filters
      @stored_filter = DataCycleCore::StoredFilter.find(permitted_download_params[:id])
      serialize_format = permitted_download_params[:serialize_format]
      languages = permitted_download_params[:language]
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.allowed?(@stored_filter, :content) && DataCycleCore::Feature::Download.enabled_serializer_for_download?(@stored_filter, :content, serialize_format)
      download_content(@stored_filter, serialize_format, Array.wrap(languages))
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
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
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def watch_list_collections
      @watch_list = DataCycleCore::WatchList.find(permitted_download_params[:id])
      serialize_formats = permitted_download_params[:serialize_format]&.split(',')&.map(&:strip) ||
                          DataCycleCore::Feature::Download
                            .enabled_serializers_for_download(@watch_list, [:archive, :zip])
                            .keys
      languages = permitted_download_params[:language]&.split(',')
      versions = params.permit(versions: {})[:versions]&.to_h

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@watch_list, [:archive, :zip], serialize_formats)

      filter = DataCycleCore::StoredFilter.new
      filter.apply_user_filter(current_user, { scope: 'download' })
      query = filter.apply(skip_ordering: true)
      query = query.watch_list_id(@watch_list.id)
      download_items = query.to_a.select { |thing| DataCycleCore::Feature::Download.allowed?(thing) }

      download_collection(@watch_list, download_items, serialize_formats, languages, versions)
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def stored_filter_collections
      @stored_filter = DataCycleCore::StoredFilter.find(permitted_download_params[:id])
      serialize_formats = permitted_download_params[:serialize_format]&.split(',')&.map(&:strip) ||
                          DataCycleCore::Feature::Download
                            .enabled_serializers_for_download(@stored_filter, [:archive, :zip])
                            .keys
      languages = permitted_download_params[:language]&.split(',')

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@stored_filter, [:archive, :zip], serialize_formats)

      @stored_filter.apply_user_filter(current_user, { scope: 'download' })
      query = @stored_filter.apply(skip_ordering: true)
      download_items = query.to_a.select { |thing| DataCycleCore::Feature::Download.allowed?(thing) }

      download_collection(@stored_filter, download_items, serialize_formats, languages)
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    # previous download feature actions, moved for ActionController::Live functionality

    def download_thing
      @object = DataCycleCore::Thing.find_by(id: permitted_download_params[:id])
      serialize_format = permitted_download_params[:serialize_format]
      languages = permitted_download_params[:language]
      version = permitted_download_params[:version]
      transformation = permitted_download_params.dig(:transformation, version)&.reject { |_k, v| v == 'none' }
      authorize! :download, @object

      download_content(@object, serialize_format, languages, version, transformation)
    rescue StandardError
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def download_thing_zip
      @object = DataCycleCore::Thing.find(permitted_download_params[:id])
      authorize! :download_zip, @object
      serialize_formats = permitted_download_params[:serialize_format]&.select { |_, v| v.to_i.positive? }&.keys
      languages = permitted_download_params[:language]

      redirect_back(fallback_location: root_path, alert: I18n.t('feature.download.missing_serialize_format', locale: helpers.active_ui_locale)) && return if serialize_formats.blank?
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@object, [:archive, :zip], serialize_formats)

      download_items = ([@object] + @object.content_b_linked).to_a.select do |thing|
        can?(:download, thing)
      end

      download_collection(@object, download_items, serialize_formats, languages)
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def download_thing_indesign
      @object = DataCycleCore::Thing.find(permitted_download_params[:id])
      authorize! :download_indesign, @object
      serialize_formats = permitted_download_params[:serialize_format]&.select { |_, v| v.to_i.positive? }&.keys
      languages = permitted_download_params[:language]

      redirect_back(fallback_location: root_path, alert: I18n.t('feature.download.missing_serialize_format', locale: helpers.active_ui_locale)) && return if serialize_formats.blank?
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@object, [:archive, :indesign], serialize_formats)

      asset_items = @object.linked_contents.where(template_name: ['Bild', 'ImageObject']).to_a.select do |thing|
        can?(:download, thing)
      end

      download_indesign_collection(@object, [@object] + asset_items, serialize_formats, languages)
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def download_data_link
      @data_link = DataCycleCore::DataLink.find_by(id: data_link_params[:id])

      raise CanCan::AccessDenied unless @data_link.try(:is_valid?) && @data_link.downloadable?

      redirect_back(fallback_location: root_path, alert: I18n.t('common.download.confirmation.terms_not_checked', locale: helpers.active_ui_locale)) && return if DataCycleCore::Feature::Download.confirmation_required? && data_link_params[:terms_of_use].to_s != '1'

      sign_in(@data_link.receiver, store: false)

      download_data_link_item(@data_link.item)
    rescue StandardError => e
      raise e, e.message if e.is_a?(CanCan::AccessDenied)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def download_stored_filter
      @stored_filter = DataCycleCore::StoredFilter.find(permitted_download_params[:id])
      serialize_format = permitted_download_params[:serialize_format]
      languages = permitted_download_params[:language]
      authorize! :download, @stored_filter
      download_content(@stored_filter, serialize_format, languages)
    rescue StandardError
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def download_stored_filter_zip
      @stored_filter = DataCycleCore::StoredFilter.find(permitted_download_params[:id])
      authorize! :download_zip, @stored_filter
      serialize_formats = permitted_download_params[:serialize_format]&.select { |_, v| v.to_i.positive? }&.keys
      languages = permitted_download_params[:language]

      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@stored_filter, [:archive, :zip], serialize_formats)

      @stored_filter.apply_user_filter(current_user, { scope: 'download' })
      query = @stored_filter.apply(skip_ordering: true)
      download_items = query.to_a.select { |thing| can?(:download, thing) }

      download_collection(@stored_filter, download_items, serialize_formats, languages)
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def download_watch_list
      @watch_list = DataCycleCore::WatchList.find(permitted_download_params[:id])
      serialize_format = permitted_download_params[:serialize_format]
      languages = permitted_download_params[:language]
      authorize! :download, @watch_list
      download_content(@watch_list, serialize_format, languages)
    rescue StandardError
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def download_watch_list_zip
      @watch_list = DataCycleCore::WatchList.find(permitted_download_params[:id])
      authorize! :download_zip, @watch_list
      serialize_formats = permitted_download_params[:serialize_format]&.select { |_, v| v.to_i.positive? }&.keys
      languages = permitted_download_params[:language]

      redirect_back(fallback_location: root_path, alert: I18n.t('feature.download.missing_serialize_format', locale: helpers.active_ui_locale)) && return if serialize_formats.blank?
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@watch_list, [:archive, :zip], serialize_formats)

      filter = DataCycleCore::StoredFilter.new
      filter.apply_user_filter(current_user, { scope: 'download' })
      query = filter.apply(skip_ordering: true)
      query = query.watch_list_id(@watch_list.id)
      download_items = query.to_a.select { |thing| can?(:download, thing) }

      download_collection(@watch_list, download_items, serialize_formats, languages)
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def download_watch_list_indesign
      @watch_list = DataCycleCore::WatchList.find(permitted_download_params[:id])
      authorize! :download_indesign, @watch_list
      serialize_formats = permitted_download_params[:serialize_format]&.select { |_, v| v.to_i.positive? }&.keys
      languages = permitted_download_params[:language]

      redirect_back(fallback_location: root_path, alert: I18n.t('feature.download.missing_serialize_format', locale: helpers.active_ui_locale)) && return if serialize_formats.blank?
      raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_formats}" unless DataCycleCore::Feature::Download.enabled_serializers_for_download?(@watch_list, [:archive, :indesign], serialize_formats)

      filter = DataCycleCore::StoredFilter.new
      filter.apply_user_filter(current_user, { scope: 'download' })
      query = filter.apply(skip_ordering: true)
      query = query.watch_list_id(@watch_list.id)
      download_items = []
      query.to_a.select do |thing|
        download_items += [thing] if ['Bild', 'ImageObject'].include?(thing.template_name) && can?(:download, thing)
        items = thing.linked_contents.where(template_name: ['Bild', 'ImageObject']).to_a.select do |linked_item|
          can?(:download, linked_item)
        end
        download_items += items
      end

      download_indesign_collection(@watch_list, download_items, serialize_formats, languages, :serialize_watch_list)
    rescue StandardError => e
      raise e, e.message if e.is_a?(DataCycleCore::Error::Download::InvalidSerializationFormatError)
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    def download_gpx
      @object = DataCycleCore::Thing.find_by(id: permitted_download_params[:id])
      download_content(@object, 'gpx', nil)
    rescue StandardError
      raise DataCycleCore::Error::Download::SerializationError, "Serialization for #{serialize_format} failed"
    end

    private

    def reset_watch_list
      @watch_list.watch_list_data_hashes.delete_all
    end

    def permitted_download_params
      params.permit(:id, :serialize_format, :version, :language, transformation: [params[:version]&.to_sym => [:format]], serialize_format: {}, language: [])
    end

    def data_link_params
      params.permit(:id, :terms_of_use)
    end

    def download_data_link_item(item)
      if item.is_a?(DataCycleCore::Thing)
        serializers = DataCycleCore::Feature::Download
          .enabled_serializers_for_download(item, [:content])
          .keys
          .first

        download_content(item, serializers, nil, nil)
      elsif item.is_a?(DataCycleCore::WatchList)
        download_items = item
          .things
          .to_a
          .select { |thing| DataCycleCore::Feature::Download.allowed?(thing) }
        serializers = DataCycleCore::Feature::Download
          .enabled_serializers_for_download(item, [:archive, :zip])
          .keys

        download_collection(item, download_items, serializers, nil, nil)
      end
    end
  end
end
