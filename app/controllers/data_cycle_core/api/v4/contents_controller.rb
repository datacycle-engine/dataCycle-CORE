# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ContentsController < ::DataCycleCore::Api::V4::ApiBaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::Filter
        before_action :prepare_url_parameters

        def index
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1
          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            query = build_search_query
            query = apply_ordering(query)

            @pagination_contents = apply_paging(query)
            @contents = @pagination_contents
            render 'index'
          end
        end

        def show
          @content = DataCycleCore::Thing
            .includes({ classifications: [], translations: [] })
            .find(permitted_params[:id])
        end

        def search
          index
        end

        def permitted_parameter_keys
          # json-api: fields, sort
          super + [:id, :language, :include, :fields, :format]
        end

        private

        def apply_ordering(query)
          query.order(DataCycleCore::Filter::Search.get_order_by_query_string(permitted_params[:q].presence))
        end

        def build_search_query
          stored_filter_id = permitted_params[:id] || nil
          if stored_filter_id.present?
            @stored_filter = DataCycleCore::StoredFilter.find(stored_filter_id)
            raise ActiveRecord::RecordNotFound if !(@stored_filter.api_users.to_a + [@stored_filter.user_id]).include?(current_user.id) && !current_user.has_rank?(99)
          end

          filter = @stored_filter || DataCycleCore::StoredFilter.new
          filter.language = @language.split(',')
          query = filter.apply

          query = query.modified_since(permitted_params.dig(:filter, :modified_since)) if permitted_params.dig(:filter, :modified_since)
          query = query.created_since(permitted_params.dig(:filter, :created_since)) if permitted_params.dig(:filter, :created_since)
          query = query.fulltext_search(permitted_params[:q]) if permitted_params[:q]

          query = query.in_validity_period

          if permitted_params&.dig(:filter, :classifications)
            permitted_params.dig(:filter, :classifications).map { |classifications|
              classifications.split(',').map(&:strip).reject(&:blank?)
            }.reject(&:empty?).each do |classifications|
              if @mode_parameters.include?('strict')
                query = query.with_classification_alias_ids_without_recursion(classifications)
              else
                query = query.classification_alias_ids(classifications)
              end
            end
          end
          query = query.with_content_ids(permitted_params&.dig(:content_id)) if permitted_params&.dig(:content_id)

          query
        end

        def apply_event_query_filters(query)
          if permitted_params&.dig(:filter, :from).present?
            query = query.event_from_time(DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :from)))
          else
            query = query.event_from_time(Time.zone.now)
          end

          query = query.event_end_time(DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :to))) if permitted_params&.dig(:filter, :to).present?
          query
        end

        def apply_place_query_filters(query)
          query = query.within_box(*permitted_params[:filter][:box].split(',').map(&:to_f)) if permitted_params&.dig(:filter, :box).present? && permitted_params&.dig(:filter, :box)&.split(',')&.size == 4
          query
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
          @include_parameters = parse_tree_params(permitted_params.dig(:include))
          @fields_parameters = parse_tree_params(permitted_params.dig(:fields))
          @field_filter = @fields_parameters.present?
          @language = permitted_params.dig(:language) || I18n.available_locales.first.to_s
          @api_subversion = permitted_params.dig(:api_subversion) if DataCycleCore.main_config.dig(:api, :v4, :subversions)&.include?(permitted_params.dig(:api_subversion))
          @api_version = 4
        end

        def parse_tree_params(raw_params)
          return [] if raw_params&.strip.blank?
          raw_params.split(',')&.map(&:strip)&.map { |item| item.split('.')&.map(&:strip) }
        end
      end
    end
  end
end
