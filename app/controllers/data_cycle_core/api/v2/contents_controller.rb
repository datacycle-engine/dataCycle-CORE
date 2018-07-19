# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ContentsController < Api::V2::ApiBaseController
        include DataCycleCore::Filter
        before_action :prepare_url_parameters

        ALLOWED_INCLUDE_PARAMETERS = ['linked', 'translations'].freeze

        def index
          query = build_search_query
          query = apply_ordering(query)

          @pagination_contents = apply_paging(query)
          @contents = @pagination_contents.map(&:content_data)
          render 'index'
        end

        def show
          object_type = content_data_type
          return if object_type.nil?
          @content = object_type
            .includes({ classifications: [], translations: [] })
            .find(permitted_params[:id])
        end

        def search
          index
        end

        # TODO: refactor
        def deleted
          deleted_contents = DataCycleCore::CreativeWork::History.where(
            DataCycleCore::CreativeWork::History.arel_table[:deleted_at].not_eq(nil)
          )

          if permitted_params[:deleted_since]
            deleted_contents = deleted_contents.where(
              DataCycleCore::CreativeWork::History.arel_table[:deleted_at].gteq(Time.zone.parse(permitted_params[:deleted_since]))
            )
          end

          @contents = apply_paging(deleted_contents)
        end

        def permitted_parameter_keys
          # json-api: fields, sort
          super + [:id, :stored_filter_id, :format, :type, :language, :q, :modified_since, :created_since, :deleted_since, :include, { filter: [{ classifications: [] }] }]
        end

        private

        def apply_ordering(query)
          if permitted_params[:q].blank?
            query
          else
            query.order(DataCycleCore::Filter::ObjectBrowserQueryBuilder.get_order_by_query_string(permitted_params[:q]))
          end
        end

        def build_search_query
          stored_filter_id = permitted_params[:id] || permitted_params[:stored_filter_id] || nil
          if stored_filter_id.present?
            @stored_filter = DataCycleCore::StoredFilter.find(stored_filter_id)
            raise ActiveRecord::RecordNotFound unless @stored_filter.api_users.include?(current_user.id)
          end

          filter = @stored_filter || DataCycleCore::StoredFilter.new
          filter.language = @language

          query = filter.apply

          query = query.where(content_data_type: content_data_type.to_s) if content_data_type
          query = query.modified_since(permitted_params[:modified_since]) if permitted_params[:modified_since]
          query = query.created_since(permitted_params[:created_since]) if permitted_params[:created_since]
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

        def prepare_url_parameters
          @url_parameters = permitted_params.reject { |k, _| k == 'format' }
          @include_parameters = (permitted_params.dig(:include)&.split(',') || []).select { |v| ALLOWED_INCLUDE_PARAMETERS.include?(v) }.sort
          @language = permitted_params.dig(:language) || I18n.available_locales.first.to_s
        end

        def content_data_type
          object_type_string = permitted_params[:type] || controller_name
          object_type = DataCycleCore.content_tables.find { |object| object == object_type_string }
          return unless object_type
          ('DataCycleCore::' + object_type.singularize.classify).constantize
        end
      end
    end
  end
end
