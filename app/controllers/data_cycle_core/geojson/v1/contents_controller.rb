# frozen_string_literal: true

# as_geojson for thing, stored_filter and watchlist
# Authorization: Basic
module DataCycleCore
  module Geojson
    module V1
      class ContentsController < ::DataCycleCore::Geojson::V1::GeojsonBaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::Filter
        # include DataCycleCore::ApiHelper
        # before_action :prepare_url_parameters

        def index
          # binding.pry
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1

          ActiveRecord::Base.transaction do
            ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql_for_conditions(['SET LOCAL statement_timeout = ?', puma_max_timeout * 1000]))

            Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
              query = build_search_query
              # query = apply_ordering(query)

              # @pagination_contents = apply_paging(query)
              # binding.pry
              @contents = query

              render plain: content_to_gejson.to_json, content_type: 'application/vnd.geo+json'
            end
          end
        end

        def show
          # binding.pry
          @content = DataCycleCore::Thing
            .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
            .find(permitted_params[:id])
          raise DataCycleCore::Error::Api::ExpiredContentError.new([{ pointer_path: request.path, type: 'expired_content', detail: 'is expired' }]), 'API Expired Content Error' unless @content.is_valid?
          # RGeo::GeoJSON.encode??
          # binding.pry
          render plain: @content.to_geojson, content_type: 'application/vnd.geo+json'
        end

        def content_to_gejson
          # binding.pry

          features = []
          @contents&.each do |content|
            features << content.as_geojson
          end

          {
            type: 'FeatureCollection',
            features: features
          }
        end

        def build_search_query
          # binding.pry
          endpoint_id = permitted_params[:id]
          @linked_stored_filter = nil
          if endpoint_id.present?
            @stored_filter = DataCycleCore::StoredFilter.find_by(id: endpoint_id)

            if @stored_filter
              # authorize! :api, @stored_filter
              @linked_stored_filter = @stored_filter.linked_stored_filter if @stored_filter.linked_stored_filter_id.present?
            elsif (@watch_list = DataCycleCore::WatchList.without_my_selection.find_by(id: endpoint_id))
            else
              raise ActiveRecord::RecordNotFound
            end
          end
          # binding.pry
          filter = @stored_filter || DataCycleCore::StoredFilter.new
          filter.language = @language
          filter.parameters = current_user.default_filter(filter.parameters, { scope: 'api' })

          query = filter.apply(skip_ordering: true)

          query = query.watch_list_id(endpoint_id) unless @watch_list.nil?

          query = query.fulltext_search(@full_text_search) if @full_text_search

          # query = query.in_validity_period
          # query = apply_filters(query, permitted_params&.dig(:filter))
          # query = append_filters(query, permitted_params)
          query
        end

        def permitted_parameter_keys
          # super + [:id, :language, :uuids, :search, :limit, uuid: []] + [filter: {}] + ['dc:liveData': [:'@id', :minPrice]]
          super + [:id]
        end
      end
    end
  end
end
