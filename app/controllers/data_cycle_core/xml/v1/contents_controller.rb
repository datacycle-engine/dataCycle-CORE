# frozen_string_literal: true

module DataCycleCore
  module Xml
    module V1
      class ContentsController < ::DataCycleCore::Xml::V1::XmlBaseController
        PUMA_MAX_TIMEOUT = 600
        include DataCycleCore::FilterConcern
        before_action :prepare_url_parameters

        ALLOWED_INCLUDE_PARAMETERS = ['linked', 'translations'].freeze
        ALLOWED_MODE_PARAMETERS = ['compact', 'minimal', 'strict', 'indesign'].freeze

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
          super + [
            :id, :stored_filter_id, :format, :type, :language, :mode, :q, :include,
            { filter: [:box, :modified_since, :created_since, :deleted_since, :from, :to, { classifications: [] }] }
          ]
        end

        private

        def apply_ordering(query)
          query = query.sort_by_proximity if content_schema_type.present? && content_schema_type == 'Event'
          query
        end

        def build_search_query
          stored_filter_id = permitted_params[:id] || nil
          if stored_filter_id.present?
            @stored_filter = DataCycleCore::StoredFilter.find(stored_filter_id)
            raise ActiveRecord::RecordNotFound if !(@stored_filter.shared_users.pluck(:id) + [@stored_filter.user_id]).include?(current_user.id) && !current_user.has_rank?(99)
          end

          filter = @stored_filter || DataCycleCore::StoredFilter.new
          filter.language = @language.split(',')
          filter.apply_user_filter(current_user, { scope: 'api' })
          query = filter.apply
          if content_schema_type
            query = query.schema_type(content_schema_type)
            query = apply_event_query_filters(query) if content_schema_type == 'Event'
            query = apply_place_query_filters(query) if content_schema_type == 'Place'
          end
          query = query.modified_at({ min: permitted_params.dig(:filter, :modified_since) }) if permitted_params.dig(:filter, :modified_since)
          query = query.created_at({ min: permitted_params.dig(:filter, :created_since) }) if permitted_params.dig(:filter, :created_since)
          query = query.fulltext_search(permitted_params[:q]) if permitted_params[:q]

          if permitted_params&.dig(:filter, :classifications)
            permitted_params.dig(:filter, :classifications).map { |classifications|
              classifications.split(',').map(&:strip).reject(&:blank?)
            }.reject(&:empty?).each do |classifications|
              if @mode_parameters.include?('strict')
                query = query.classification_alias_ids_without_subtree(classifications)
              else
                query = query.classification_alias_ids_with_subtree(classifications)
              end
            end
          end
          query = query.content_ids(permitted_params&.dig(:content_id)) if permitted_params&.dig(:content_id)

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
          @url_parameters = permitted_params.except('format')
          @include_parameters = (permitted_params.dig(:include)&.split(',') || []).select { |v| ALLOWED_INCLUDE_PARAMETERS.include?(v) }.sort
          @mode_parameters = (permitted_params.dig(:mode)&.split(',') || []).select { |v| ALLOWED_MODE_PARAMETERS.include?(v) }.sort
          @language = permitted_params.dig(:language) || I18n.available_locales.first.to_s
          @api_subversion = permitted_params.dig(:api_subversion) if DataCycleCore.main_config.dig(:api, :v3, :subversions)&.include?(permitted_params.dig(:api_subversion))
          @api_version = 1
        end

        def content_schema_type
          excluded_controller_names = ['things', 'contents']
          return permitted_params.dig(:type)&.classify if permitted_params.dig(:type).present?
          return controller_name.classify unless excluded_controller_names.include?(controller_name)
          nil
        end
      end
    end
  end
end
