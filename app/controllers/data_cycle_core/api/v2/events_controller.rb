# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class EventsController < DataCycleCore::Api::V2::ContentsController
        def index
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
          query = query.in_validity_period if permitted_params[:modified_since] && permitted_params[:created_since]
          query = query.fulltext_search(permitted_params[:q]) if permitted_params[:q]

          if permitted_params&.dig(:filter, :classifications)
            permitted_params.dig(:filter, :classifications).map { |classifications|
              classifications.split(',').map(&:strip).reject(&:blank?)
            }.reject(&:empty?).each do |classifications|
              query = query.classification_alias_ids(classifications)
            end
          end

          if permitted_params&.dig(:filter, :from).present?
            query = query.event_from_time(DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :from)))
          else
            query = query.event_from_time(Time.zone.now)
          end

          if permitted_params&.dig(:filter, :to).present?
            query = query.event_end_time(DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :to)))
          end

          @pagination_contents = apply_paging(query.sort_by_proximity)
          @contents = @pagination_contents
        end

        def permitted_parameter_keys
          super + [{ filter: [:from, :to, { classifications: [] }] }]
        end
      end
    end
  end
end
