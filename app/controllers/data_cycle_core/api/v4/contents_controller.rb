# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ContentsController < ::DataCycleCore::Api::V4::ApiBaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::FilterConcern
        include DataCycleCore::ApiHelper
        before_action :prepare_url_parameters

        def index
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1

          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            query = build_search_query

            if request.format.geojson?
              raise ActiveRecord::RecordNotFound unless DataCycleCore.features.dig(:serialize, :serializers, :geojson) == true

              render(plain: query.query.to_geojson(include_parameters: @include_parameters, fields_parameters: @fields_parameters, classification_trees_parameters: @classification_trees_parameters), content_type: request.format.to_s)
              return
            end

            @pagination_contents = apply_paging(query)
            @contents = @pagination_contents

            if (@watch_list || @stored_filter)&.id.present?
              @pagination_url = method(:api_v4_stored_filter_url)
            else
              @pagination_url = method(:api_v4_things_url)
            end

            renderer = DataCycleCore::ApiRenderer::ThingRendererV4.new(
              contents: @contents,
              request_method: request.request_method,
              **thing_renderer_v4_params
            )
            render json: renderer.render(:json)
          end
        end

        def show
          @content = DataCycleCore::Thing.find(permitted_params[:id])

          raise DataCycleCore::Error::Api::ExpiredContentError.new([{ pointer_path: request.path, type: 'expired_content', detail: 'is expired' }]), 'API Expired Content Error' unless @content.is_valid?

          depth = @include_parameters&.map(&:size)&.max
          @content.instance_variable_set(:@_recursive_preload_depth, 1 + depth) if depth

          if request.format.geojson? # rubocop:disable Style/GuardClause
            raise ActiveRecord::RecordNotFound unless DataCycleCore.features.dig(:serialize, :serializers, :geojson) == true

            render(plain: @content.to_geojson(include_parameters: @include_parameters, fields_parameters: @fields_parameters, classification_trees_parameters: @classification_trees_parameters), content_type: request.format.to_s) && return
          end

          renderer = DataCycleCore::ApiRenderer::ThingRendererV4.new(
            content: @content,
            request_method: request.request_method,
            **thing_renderer_v4_params
          )
          render json: renderer.render(:json)
        end

        def timeseries
          content = DataCycleCore::Thing.find(timeseries_params[:content_id] || timeseries_params[:id])

          raise CanCan::AccessDenied unless DataCycleCore::StoredFilter.new.apply_user_filter(current_user, { scope: 'api' }).apply(skip_ordering: true).query.exists?(id: content.id)

          @renderer = DataCycleCore::ApiRenderer::TimeseriesRenderer.new(content:, **timeseries_params.slice(:timeseries, :group_by, :time, :data_format).to_h.deep_symbolize_keys)

          case permitted_params[:format].to_sym
          when :json
            begin
              render json: @renderer.render(:json)
            rescue DataCycleCore::ApiRenderer::Error::RendererError => e
              render json: { error: e.message }, status: :bad_request
            end
          when :csv
            response.headers['Content-Type'] = 'text/csv'
            response.headers['Content-Disposition'] = "attachment; filename=#{content.id}_#{permitted_params[:timeseries]}.csv"

            begin
              render plain: @renderer.render(:csv)
            rescue DataCycleCore::ApiRenderer::Error::RendererError => e
              render plain: ['error', e.message].join("\n"), status: :bad_request
            end
          end
        end

        def elevation_profile
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1

          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            query = build_search_query
            content = query.query.find(timeseries_params[:content_id])

            @renderer = DataCycleCore::ApiRenderer::ElevationProfileRenderer.new(content:, **timeseries_params.slice(:data_format).to_h.deep_symbolize_keys)

            begin
              render json: @renderer.render
            rescue DataCycleCore::ApiRenderer::Error::RendererError => e
              render json: { error: e.message }, status: e.status_code
            end
          end
        end

        def statistics
          query = build_search_query
          endpoint = @watch_list || @stored_filter

          @renderer = DataCycleCore::ApiRenderer::StatisticsRenderer.new(query: query.query, **statistics_params.slice(:attribute, :group_by, :time, :data_format).to_h.deep_symbolize_keys)

          case permitted_params[:format].to_sym
          when :json
            begin
              render json: @renderer.render(:json)
            rescue DataCycleCore::ApiRenderer::Error::RendererError => e
              render json: { error: e.message }, status: :bad_request
            end
          when :csv
            response.headers['Content-Type'] = 'text/csv'
            response.headers['Content-Disposition'] = "attachment; filename=#{endpoint.id}_#{permitted_params[:attribute]}.csv"

            begin
              render plain: @renderer.render(:csv)
            rescue DataCycleCore::ApiRenderer::Error::RendererError => e
              render plain: ['error', e.message].join("\n"), status: :bad_request
            end
          end
        end

        def select
          @uuid = permitted_params[:uuid]
          @uuids = permitted_params[:uuids]
          uuid = @uuid || @uuids&.split(',')
          if uuid.present? && uuid.is_a?(::Array) && uuid.size.positive?
            query = DataCycleCore::Thing
              .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
              .where(id: uuid)

            if request.format.geojson?
              raise ActiveRecord::RecordNotFound unless DataCycleCore.features.dig(:serialize, :serializers, :geojson) == true

              render(plain: query.to_geojson(include_parameters: @include_parameters, fields_parameters: @fields_parameters, classification_trees_parameters: @classification_trees_parameters), content_type: request.format.to_s)
              return
            end

            @contents = apply_paging(query)
            @pagination_url = method(:api_v4_contents_select_url)

            render 'index'
          else
            render json: { error: 'No ids given!' }, layout: false, status: :bad_request
          end
        end

        def select_by_external_keys
          @external_source_id = permitted_params[:external_source_id]
          @external_keys = permitted_params[:external_keys]&.split(',')

          if @external_keys.present? && @external_keys.is_a?(::Array) && @external_keys.size.positive?
            query = build_search_query
            query = query.query
              .by_external_key(@external_source_id, @external_keys)
              .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])

            @contents = apply_paging(query)
            @pagination_url = method(:api_v4_things_select_by_external_key_url)

            render 'index'
          else
            render json: { error: 'No ids given!' }, layout: false, status: :bad_request
          end
        end

        def typeahead
          query = build_search_query
          result = query.typeahead(permitted_params[:search], @language, permitted_params[:limit] || 10)
          words = result.to_a.pluck('word') # score not needed
          render json: {
            '@context' => api_plain_context(@language),
            '@graph' => {
              '@type' => 'dcls:Statistics',
              'suggest' => words
            }
          }
        end

        def typeahead_by_title
          query = build_search_query
          words = query.typeahead_by_title(permitted_params[:search], @language, permitted_params[:limit] || 10)

          render json: {
            '@context' => api_plain_context(@language),
            '@graph' => {
              '@type' => 'dcls:Statistics',
              'suggest' => words
            }
          }
        end

        def deleted
          deleted_contents = DataCycleCore::Thing::History.where.not(deleted_at: nil).where.not(content_type: 'embedded')

          if permitted_params&.dig(:filter, :attribute, :'dct:deleted').present?
            filter = permitted_params[:filter][:attribute][:'dct:deleted'].to_h.deep_symbolize_keys
            filter.each do |operator, value|
              query_string = apply_timestamp_query_string(value, "#{deleted_contents.table.name}.deleted_at")
              if operator == :in
                deleted_contents = deleted_contents.where(query_string)
              elsif operator == :notIn
                deleted_contents = deleted_contents.where.not(query_string)
              end
            end
          end

          deleted_contents = deleted_contents.reorder(nil).order('deleted_at DESC')

          render plain: list_api_deleted_request(apply_paging(deleted_contents)).to_json, content_type: 'application/json'
        end

        def statistics_params
          params.transform_keys(&:underscore).permit(:id, :attribute, :data_format, :group_by, time: {})
        end

        def timeseries_params
          params.permit(:id, :content_id, :timeseries, :dataFormat, :groupBy, time: {}).transform_keys(&:underscore)
        end

        def permitted_parameter_keys
          super + [:id, :language, :uuids, :external_source_id, :external_keys, :search, :limit, :weight, {uuid: [], filter: {}, 'dc:liveData': [:@id, :minPrice]}]
        end

        # @todo: remove obsolete method?
        def permitted_filter_parameters
          {
            filter:
              attribute_filters + [linked: {}] + [union: []]
          }
        end

        private

        def thing_renderer_v4_params
          DataCycleCore::ApiRenderer::ThingRendererV4::JSON_RENDER_PARAMS
            .index_with { |p| instance_variable_get(:"@#{p}") }
        end
      end
    end
  end
end
