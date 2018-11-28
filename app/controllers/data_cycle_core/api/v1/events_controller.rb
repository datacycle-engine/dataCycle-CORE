# frozen_string_literal: true

module DataCycleCore
  module Api
    module V1
      class EventsController < DataCycleCore::Api::V1::ContentsController
        def index
          query = DataCycleCore::Thing.includes(:translations, :classifications).with_schema_type('Event').with_content_type('entity')
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
          @contents = apply_paging(query).sort_by_proximity
        end

        def show
          @content = DataCycleCore::Thing.with_schema_type('Event').includes(:classifications, :translations).find(permitted_params[:id])
        end

        def permitted_parameter_keys
          super + [:id, :q, { filter: [:from, :to, { classifications: [] }] }]
        end
      end
    end
  end
end
