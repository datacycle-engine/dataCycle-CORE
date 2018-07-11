# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      module Filter
        extend ActiveSupport::Concern

        def filter_query(query)
          filter_method = "filter_#{content_data_type&.name&.demodulize&.downcase}"
          return send(filter_method,query) if respond_to?(filter_method)

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

          query
        end

        def apply_ordering(query)
          if permitted_params[:q].blank?
            query
          else
            query.order(DataCycleCore::Filter::ObjectBrowserQueryBuilder.get_order_by_query_string(permitted_params[:q]))
          end
        end

        def filter_event(query)
          if permitted_params&.dig(:q)
            query = query.search(permitted_params&.dig(:q), permitted_params.fetch(:language, DataCycleCore.ui_language))
          end

          if permitted_params&.dig(:filter, :from)
            query = query.from_time(DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :from)))
          else
            query = query.from_time(Time.zone.now)
          end

          if permitted_params&.dig(:filter, :to)
            query = query.to_time(DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :to)))
          end

          if permitted_params&.dig(:filter, :classifications)
            permitted_params.dig(:filter, :classifications).map { |classifications|
              classifications.split(',').map(&:strip).reject(&:blank?)
            }.reject(&:empty?).each do |classifications|
              query = query.with_classification_alias_ids(classifications)
            end
          end

          query = query.with_translations(permitted_params.fetch(:language, DataCycleCore.ui_language))
          query
        end

      end
    end
  end
end

