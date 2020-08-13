# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ContentsController < ::DataCycleCore::Api::V4::ApiBaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::Filter
        include DataCycleCore::ApiHelper
        include DataCycleCore::ApiService
        before_action :prepare_url_parameters
        rescue_from DataCycleCore::Error::Api::TimeOutError, with: :too_many_requests

        ALLOWED_SORT_ATTRIBUTES = { created: 'created_at', modified: 'updated_at', name: 'name', given_name: 'given_name', family_name: 'family_name', random: 'random' }.freeze
        ALLOWED_FILTER_ATTRIBUTES = [:modifiedAt, :createdAt, :schedule].freeze

        def index
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1
          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            query = build_search_query
            # query = build_search_query.includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
            query = apply_ordering(query)

            @pagination_contents = apply_paging(query)
            @contents = @pagination_contents

            if list_api_request?
              render plain: list_api_request.to_json, content_type: 'application/json'
            else
              render 'index'
            end
          end
        end

        def show
          @content = DataCycleCore::Thing
            .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
            .find(permitted_params[:id])
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

          if permitted_params&.dig(:filter, :attribute, :deletedAt).present?
            filter = permitted_params[:filter][:attribute][:deletedAt].to_h.deep_symbolize_keys
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
          super + [:id, :language, :uuids, uuid: []] + [permitted_filter_parameters]
        end

        def permitted_filter_parameters
          {
            filter:
              [
                :search,
                :q,
                {
                  classifications: {
                    in: {
                      withSubtree: [],
                      withoutSubtree: []
                    },
                    notIn: {
                      withSubtree: [],
                      withoutSubtree: []
                    }
                  }
                },
                {
                  attribute: {
                    createdAt: attribute_filter_operations,
                    deletedAt: attribute_filter_operations,
                    modifiedAt: attribute_filter_operations,
                    schedule: attribute_filter_operations
                  }
                },
                {
                  geo: {
                    in: {
                      box: [],
                      perimeter: [],
                      shapes: []
                    },
                    notIn: {
                      box: [],
                      perimeter: [],
                      shapes: []
                    }
                  }
                }
              ]
          }
        end

        private

        def list_api_request?
          return true if @include_parameters.blank? && select_attributes(@fields_parameters).include?('dct:modified') && select_attributes(@fields_parameters).size == 1
          false
        end

        def apply_ordering(query)
          apply_order_query(query, permitted_params.dig(:sort), @full_text_search, permitted_params&.dig(:filter, :attribute, :schedule).present?)
        end

        def transform_sort_param(key, order)
          return unless ALLOWED_SORT_ATTRIBUTES.key?(key.to_sym)
          return "#{key.to_sym}()" if ALLOWED_SORT_ATTRIBUTES.dig(key.to_sym) == 'random'
          "#{ALLOWED_SORT_ATTRIBUTES.dig(key.to_sym)} #{order} NULLS LAST"
        end

        def build_search_query
          endpoint_id = permitted_params[:id]
          @linked_stored_filter = nil
          if endpoint_id.present?
            @stored_filter = DataCycleCore::StoredFilter.find_by(id: endpoint_id)

            if @stored_filter
              authorize! :api, @stored_filter
              @linked_stored_filter = @stored_filter.linked_stored_filter if @stored_filter.linked_stored_filter_id.present?
            elsif (@watch_list = DataCycleCore::WatchList.find_by(id: endpoint_id))
            else
              raise ActiveRecord::RecordNotFound
            end
          end

          filter = @stored_filter || DataCycleCore::StoredFilter.new
          filter.language = @language
          filter.parameters = current_user.default_filter(filter.parameters, { scope: 'api' })
          query = filter.apply
          query = query.watch_list_id(endpoint_id) unless @watch_list.nil?

          query = query.fulltext_search(@full_text_search) if @full_text_search

          query = query.in_validity_period

          query = apply_classification_filters(query)
          query = apply_attribute_filters(query)
          query = apply_geo_filters(query)

          query = query.with_content_ids(permitted_params&.dig(:content_id)) if permitted_params&.dig(:content_id)
          query = query.distinct_by_content_id

          query
        end
      end
    end
  end
end
