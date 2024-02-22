# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class DownloadsController < ::DataCycleCore::Api::V4::ApiBaseController
        include DataCycleCore::FilterConcern
        include DataCycleCore::DownloadHandler if DataCycleCore::Feature::Download.enabled?
        before_action :prepare_url_parameters

        def endpoint
          query = build_search_query

          @collection = @watch_list || @stored_filter
          serialize_format = download_params[:serialize_format]
          @contents = query.query
          additional_data = {
            name: download_params.dig(:meta, :collection, :name),
            filter: permitted_params[:filter].to_h
          }

          raise ActiveRecord::RecordNotFound unless @collection&.persisted?
          raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.allowed?(@collection, :content) && DataCycleCore::Feature::Download.enabled_serializer_for_download?(@collection, :content, serialize_format)

          download_filtered_collection(@collection, query.query, serialize_format, @language, additional_data)
        end

        def thing
          raise ActiveRecord::RecordNotFound unless download_params[:content_id]&.uuid?

          query = build_search_query
          @content = query.query.find(download_params[:content_id])
          serialize_format = download_params[:serialize_format]

          raise DataCycleCore::Error::Download::InvalidSerializationFormatError, "invalid serialization format: #{serialize_format}" unless DataCycleCore::Feature::Download.allowed?(@content, :content) && DataCycleCore::Feature::Download.enabled_serializer_for_download?(@content, :content, serialize_format)

          download_content(@content, serialize_format, @language)
        end

        private

        def permitted_parameter_keys
          super + [:id, :language, :search, filter: {}, meta: [collection: [:name]]]
        end

        def download_params
          params.permit(:content_id, :serialize_format, meta: [collection: [:name]])
        end

        def validate_params_exceptions
          super + [:meta, :serialize_format]
        end
      end
    end
  end
end
