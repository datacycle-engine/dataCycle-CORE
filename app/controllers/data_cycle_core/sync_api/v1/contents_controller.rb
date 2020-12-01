# frozen_string_literal: true

module DataCycleCore
  module SyncApi
    module V1
      class ContentsController < ::DataCycleCore::SyncApi::V1::BaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::Filter
        before_action :prepare_url_parameters

        def index
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1
          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            query = build_search_query

            @pagination_contents = apply_paging(query)
            @contents = @pagination_contents

            render 'index'
          end
        end

        def show
          @content = DataCycleCore::Thing
            .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
            .find(permitted_params[:id])
          raise DataCycleCore::Error::Api::ExpiredContentError.new([{ pointer_path: request.path, type: 'expired_content', detail: 'is expired' }]), 'API Expired Content Error' unless @content.is_valid?
          render json: @content.to_sync_data.to_json
        end

        def select
          uuid = permitted_params[:uuid] || permitted_params[:uuids]&.split(',')
          if uuid.present? && uuid.is_a?(::Array) && uuid.size.positive?
            fetched_things = DataCycleCore::Thing
              .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
              .where(id: uuid)
            @contents = apply_paging(fetched_things)
            render 'index'
          else
            render json: { error: 'No ids given!' }, layout: false, status: :bad_request
          end
        end

        def deleted
          deleted_contents = DataCycleCore::Thing::History.where(
            DataCycleCore::Thing::History.arel_table[:deleted_at].not_eq(nil)
          )

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
          super + [:id, :language, :delted_at, :uuids, uuid: []]
        end

        private

        def build_search_query
          query = append_filters(query, permitted_params)
          query
        end

        def list_api_deleted_request(contents)
          json_context = api_plain_context(@language)
          json_contents = contents.map do |item|
            Rails.cache.fetch(sync_api_v1_cache_key(item, @language, @include_parameters, @fields_parameters, @api_subversion), expires_in: 1.year + Random.rand(7.days)) do
              item.to_api_deleted_list
            end
          end
          json_links = api_plain_links(contents)
          list_hash = {
            '@context' => json_context,
            '@graph' => json_contents,
            'links' => json_links
          }
          list_hash['meta'] = api_plain_meta(contents.total_count, contents.total_pages) unless @permitted_params.dig(:section, :meta)&.to_i&.zero?
          list_hash
        end
      end
    end
  end
end
