# frozen_string_literal: true

module DataCycleCore
  module Api
    module V3
      class ContentsController < ::DataCycleCore::Api::V3::ApiBaseController
        include DataCycleCore::Filter
        before_action :prepare_url_parameters

        ALLOWED_INCLUDE_PARAMETERS = ['linked', 'translations'].freeze
        ALLOWED_MODE_PARAMETERS = ['compact', 'minimal'].freeze

        def index
          query = build_search_query
          query = apply_ordering(query)

          @pagination_contents = apply_paging(query)
          @contents = @pagination_contents
          render 'index'
        end

        def show
          @content = DataCycleCore::Thing
            .includes({ classifications: [], translations: [] })
            .find(permitted_params[:id])
        end

        def search
          index
        end

        def deleted
          deleted_contents = DataCycleCore::Thing::History.where(
            DataCycleCore::Thing::History.arel_table[:deleted_at].not_eq(nil)
          )

          if permitted_params.dig(:filter, :deleted_since)
            deleted_contents = deleted_contents.where(
              DataCycleCore::Thing::History.arel_table[:deleted_at].gteq(Time.zone.parse(permitted_params.dig(:filter, :deleted_since)))
            )
          end

          @contents = apply_paging(deleted_contents)
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
          if permitted_params[:q].blank?
            query
          else
            query.order(DataCycleCore::Filter::Search.get_order_by_query_string(permitted_params[:q]))
          end
        end

        def build_search_query
          stored_filter_id = permitted_params[:id] || nil
          if stored_filter_id.present?
            @stored_filter = DataCycleCore::StoredFilter.find(stored_filter_id)
            raise ActiveRecord::RecordNotFound unless (@stored_filter.api_users + [@stored_filter.user_id]).include?(current_user.id)
          end

          filter = @stored_filter || DataCycleCore::StoredFilter.new
          filter.language = @language.split(',')

          query = filter.apply
          if content_schema_type
            query = query.where(searches: { schema_type: content_schema_type })
            query = apply_event_query_filters(query) if content_schema_type == 'Event'
            query = apply_place_query_filters(query) if content_schema_type == 'Place'
          end
          # query = query.where(schema_type: content_schema_type) if content_schema_type
          query = query.modified_since(permitted_params.dig(:filter, :modified_since)) if permitted_params.dig(:filter, :modified_since)
          query = query.created_since(permitted_params.dig(:filter, :created_since)) if permitted_params.dig(:filter, :created_since)
          query = query.fulltext_search(permitted_params[:q]) if permitted_params[:q]

          query = query.in_validity_period

          if permitted_params&.dig(:filter, :classifications)
            permitted_params.dig(:filter, :classifications).map { |classifications|
              classifications.split(',').map(&:strip).reject(&:blank?)
            }.reject(&:empty?).each do |classifications|
              query = query.classification_alias_ids(classifications)
            end
          end
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
          @include_parameters = (permitted_params.dig(:include)&.split(',') || []).select { |v| ALLOWED_INCLUDE_PARAMETERS.include?(v) }.sort
          @mode_parameters = (permitted_params.dig(:mode)&.split(',') || []).select { |v| ALLOWED_MODE_PARAMETERS.include?(v) }.sort
          @language = permitted_params.dig(:language) || I18n.available_locales.first.to_s

          @api_version = 3
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