# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ThingsController < DataCycleCore::Api::V2::ContentsController
        private

        def build_search_query
          stored_filter_id = permitted_params[:id] || permitted_params[:stored_filter_id] || nil
          if stored_filter_id.present?
            @stored_filter = DataCycleCore::StoredFilter.find(stored_filter_id)
            raise ActiveRecord::RecordNotFound unless (@stored_filter.api_users + [@stored_filter.user_id]).include?(current_user.id)
          end

          filter = @stored_filter || DataCycleCore::StoredFilter.new
          filter.language = @language.split(',')

          query = filter.apply
          query = query.where(content_data_type: 'DataCycleCore::Thing')
          query = query.where(schema_type: content_schema_type) if content_schema_type && controller_name != 'things'
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

        def content_schema_type
          permitted_params[:type] || controller_name.classify
        end
      end
    end
  end
end
