# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ContentsController < ::DataCycleCore::Api::V4::ApiBaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::Filter
        include DataCycleCore::ApiHelper
        before_action :prepare_url_parameters
        rescue_from DataCycleCore::Error::Api::TimeOutError, with: :too_many_requests

        def index
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1
          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            query = build_search_query
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
          raise DataCycleCore::Error::Api::ExpiredContentError.new([{ pointer_path: request.path, type: 'expired_content', detail: 'is expired' }]), 'API Expired Content Error' unless @content.is_valid?
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

          deleted_contents = deleted_contents.except(:order).order('deleted_at DESC')

          render plain: list_api_deleted_request(apply_paging(deleted_contents)).to_json, content_type: 'application/json'
        end

        def permitted_parameter_keys
          super + [:id, :language, :uuids, uuid: []] + [permitted_filter_parameters]
        end

        def permitted_filter_parameters
          {
            filter:
              attribute_filters + [linked: {}]
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

          query = apply_filters(query, permitted_params&.dig(:filter))

          query = query.with_content_ids(permitted_params&.dig(:content_id)) if permitted_params&.dig(:content_id)
          query
        end
      end
    end
  end
end
