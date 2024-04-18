# frozen_string_literal: true

module DataCycleCore
  module SyncApi
    module V1
      class ContentsController < ::DataCycleCore::SyncApi::V1::BaseController
        PUMA_MAX_TIMEOUT = 600
        include DataCycleCore::FilterConcern
        before_action :prepare_url_parameters

        def index
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1
          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            query = build_search_query

            return render(json: { '@graph': query.query.reorder(nil).pluck(:id) }) if permitted_params[:index_only].to_s == 'true'

            @pagination_contents = apply_paging(query)
            @contents = @pagination_contents
            render json: sync_api_format(@contents) { @contents.to_sync_data(linked_stored_filter: @linked_stored_filter) }.to_json
          end
        end

        def show
          if (@contents = DataCycleCore::Thing.where(id: permitted_params[:id]).limit(1)).present?
            render json: @contents.to_sync_data&.first.to_json
          else
            render json: { error: 'Id not found!' }, layout: false, status: :bad_request
          end
        end

        def select
          uuid = permitted_params[:uuid] || permitted_params[:uuids]&.split(',')
          if uuid.present? && uuid.is_a?(::Array) && uuid.size.positive?
            fetched_things = DataCycleCore::Thing
              .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
              .where(id: uuid)
            @contents = apply_paging(fetched_things)
            render json: sync_api_format(@contents) { @contents.to_sync_data }.to_json
          else
            render json: { error: 'No ids given!' }, layout: false, status: :bad_request
          end
        end

        def deleted
          deleted_contents = DataCycleCore::Thing::History.where.not(deleted_at: nil).where.not(content_type: 'embedded')

          if permitted_params&.dig(:deleted_at).present?
            filter = permitted_params[:deleted_at].to_h.deep_symbolize_keys
            filter.each do |operator, value|
              query_string = apply_timestamp_query_string(value, "#{deleted_contents.table.name}.deleted_at")
              if operator == :in
                deleted_contents = deleted_contents.where(query_string)
              elsif operator == :notIn
                deleted_contents = deleted_contents.where.not(query_string)
              end
            end
          end

          deleted_contents = deleted_contents.except(:order).order('deleted_at DESC')

          render plain: list_api_deleted_request(apply_paging(deleted_contents)).to_json, content_type: 'application/json'
        end

        def permitted_parameter_keys
          super + [:id, :language, :deleted_at, :updated_since, :uuids, :index_only, uuid: []]
        end

        private

        def build_search_query
          endpoint_id = permitted_params[:id]
          @linked_stored_filter = nil
          if endpoint_id.present?
            @stored_filter = DataCycleCore::StoredFilter.find_by(id: endpoint_id)

            if @stored_filter
              authorize! :api, @stored_filter
              @linked_stored_filter = @stored_filter.linked_stored_filter if @stored_filter.linked_stored_filter_id.present?
            elsif (@watch_list = DataCycleCore::WatchList.without_my_selection.find_by(id: endpoint_id))
            else
              raise ActiveRecord::RecordNotFound
            end
          end
          filter = @stored_filter || DataCycleCore::StoredFilter.new
          filter.language = @language
          filter.parameters = current_user.default_filter(filter.parameters, { scope: 'api' })
          query = filter.apply

          query = query.watch_list_id(endpoint_id) unless @watch_list.nil?
          query = query.content_ids(params[:content_id]) if params&.dig(:content_id).present?
          query = query.updated_since(@updated_since) if @updated_since.present?

          query
        end

        def list_api_deleted_request(contents)
          json_contents = contents.map do |item|
            Rails.cache.fetch(sync_api_v1_cache_key(item, @language, @include_parameters, @fields_parameters, @api_subversion), expires_in: 1.year + Random.rand(7.days)) do
              item.to_sync_api_deleted
            end
          end
          sync_api_format(contents) { json_contents }
        end

        def sync_api_format(contents)
          {
            '@graph' => yield,
            'links' => api_plain_links(contents),
            'meta' => api_plain_meta(contents.total_count, contents.total_pages)
          }
        end

        def api_plain_links(contents = nil)
          contents ||= @contents
          object_url = lambda do |params|
            File.join(request.protocol + request.host + ':' + request.port.to_s, request.path) + '?' + params.to_query
          end
          if request.request_method == 'POST'
            common_params = {}
          else
            common_params = @permitted_params.to_h.except('id', 'format', 'page', 'api_subversion')
          end
          links = {}
          links[:prev] = object_url.call(common_params.merge(page: { number: contents.prev_page, size: contents.limit_value })) if contents.prev_page
          links[:next] = object_url.call(common_params.merge(page: { number: contents.next_page, size: contents.limit_value })) if contents.next_page
          links
        end

        def api_plain_meta(count, pages)
          {
            total: count,
            pages:
          }
        end
      end
    end
  end
end
