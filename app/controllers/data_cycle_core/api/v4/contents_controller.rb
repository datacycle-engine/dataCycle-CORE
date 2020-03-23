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

        def deleted
          deleted_contents = DataCycleCore::Thing::History.where(
            DataCycleCore::Thing::History.arel_table[:deleted_at].not_eq(nil)
          )

          if permitted_params.dig(:filter, :deletedSince)
            deleted_contents = deleted_contents.where(
              DataCycleCore::Thing::History.arel_table[:deleted_at].gteq(Time.zone.parse(permitted_params.dig(:filter, :deletedSince)))
            )
          end

          render plain: list_api_request(apply_paging(deleted_contents)).to_json, content_type: 'application/json'
        end

        def permitted_parameter_keys
          # json-api: sort
          super + [
            :id, :language, :include, :fields, :format,
            { filter: [:search, :box, :modifiedSince, :createdSince, :deletedSince, :from, :to, { 'classifications.with_subtree': [], 'classifications.without_subtree': [] }] }
          ]
        end

        private

        def list_api_request?
          return true if @include_parameters.blank? && select_attributes(@fields_parameters).include?('dct:modified') && select_attributes(@fields_parameters).size == 1
          false
        end

        def apply_ordering(query)
          query.except(:order).order(DataCycleCore::Filter::Search.get_order_by_query_string(permitted_params[:search].presence, permitted_params&.dig(:filter, :from).present? || permitted_params&.dig(:filter, :to).present?))
        end

        def build_search_query
          endpoint_id = permitted_params[:id]
          filter_watch_list = false
          @linked_stored_filter = nil
          if endpoint_id.present?
            @stored_filter = DataCycleCore::StoredFilter.find_by(id: endpoint_id)

            if @stored_filter
              authorize! :api, @stored_filter
              @linked_stored_filter = @stored_filter.linked_stored_filter if @stored_filter.linked_stored_filter_id.present?
            elsif DataCycleCore::WatchList.exists?(id: endpoint_id)
              filter_watch_list = true
            else
              raise ActiveRecord::RecordNotFound
            end
          end

          filter = @stored_filter || DataCycleCore::StoredFilter.new
          filter.language = @language
          filter.parameters = current_user.default_filter(filter.parameters, { scope: 'api' })
          query = filter.apply(experimental: true)
          query = query.watch_list_id(endpoint_id) if filter_watch_list
          query = apply_event_query_filters(query)
          query = apply_place_query_filters(query)

          query = query.modifiedSince(permitted_params.dig(:filter, :modifiedSince)) if permitted_params.dig(:filter, :modifiedSince)
          query = query.createdSince(permitted_params.dig(:filter, :createdSince)) if permitted_params.dig(:filter, :createdSince)
          query = query.fulltext_search(permitted_params.dig(:filter, :search)) if permitted_params.dig(:filter, :search)

          query = query.in_validity_period

          query = apply_classification_filters(query)

          query = query.with_content_ids(permitted_params&.dig(:content_id)) if permitted_params&.dig(:content_id)
          query = query.distinct_by_content_id
          query
        end

        def apply_classification_filters(query)
          return query if permitted_params&.dig(:filter, 'classifications.with_subtree').blank? && permitted_params&.dig(:filter, 'classifications.without_subtree').blank?
          with_subtree = permitted_params&.dig(:filter, 'classifications.with_subtree')
          without_subtree = permitted_params&.dig(:filter, 'classifications.without_subtree')

          if with_subtree.present?
            with_subtree.map { |classifications|
              classifications.split(',').map(&:strip).reject(&:blank?)
            }.reject(&:empty?).each do |classifications|
              query = query.classification_alias_ids_with_subtree(classifications)
            end
          end

          if without_subtree.present?
            without_subtree.map { |classifications|
              classifications.split(',').map(&:strip).reject(&:blank?)
            }.reject(&:empty?).each do |classifications|
              query = query.classification_alias_ids_without_subtree(classifications)
            end
          end

          query
        end

        def apply_event_query_filters(query)
          return query unless permitted_params&.dig(:filter, :from).present? || permitted_params&.dig(:filter, :to).present?
          from_date = nil
          to_date = nil
          from_date = DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :from)) if permitted_params&.dig(:filter, :from).present?
          to_date = DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :to)) if permitted_params&.dig(:filter, :to).present?

          query.schedule_search(from_date, to_date)
        end

        def apply_place_query_filters(query)
          return query unless permitted_params&.dig(:filter, :box).present? && permitted_params&.dig(:filter, :box)&.split(',')&.size == 4
          query.within_box(*permitted_params[:filter][:box].split(',').map(&:to_f))
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
          @include_parameters = parse_tree_params(permitted_params.dig(:include))
          @fields_parameters = parse_tree_params(permitted_params.dig(:fields))
          @mode_parameters = permitted_params.dig(:mode)
          @field_filter = @fields_parameters.present?
          @language = parse_language(permitted_params.dig(:language)).presence || Array(I18n.available_locales.first.to_s)
          @api_subversion = permitted_params.dig(:api_subversion) if DataCycleCore.main_config.dig(:api, :v4, :subversions)&.include?(permitted_params.dig(:api_subversion))
          @api_version = 4
        end
      end
    end
  end
end
