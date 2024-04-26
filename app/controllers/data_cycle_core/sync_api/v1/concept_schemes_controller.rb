# frozen_string_literal: true

module DataCycleCore
  module SyncApi
    module V1
      class ConceptSchemesController < ::DataCycleCore::SyncApi::V1::BaseController
        PUMA_MAX_TIMEOUT = 600

        def index
          raise ActionController::BadRequest if permitted_params[:ids].blank?

          @concept_schemes = DataCycleCore::ConceptScheme.where(id: permitted_params[:ids].split(',').map(&:strip))
          @concept_schemes = @concept_schemes.where('concept_schemes.updated_at >= ?', permitted_params[:updated_since].in_time_zone) if permitted_params[:updated_since].present?
          @concept_schemes = apply_paging(@concept_schemes).without_count

          render json: sync_api_format(@concept_schemes).to_json
        end

        def show
          @concept_scheme = DataCycleCore::ConceptScheme.find(permitted_params[:id])

          render json: { '@graph' => Array.wrap(@concept_scheme.to_sync_data) }.to_json
        end

        def concepts
          @concept_scheme = DataCycleCore::ConceptScheme.find(permitted_params[:id])
          @concepts = @concept_scheme.concepts
          @concepts = @concepts.where('concepts.updated_at >= ?', permitted_params[:updated_since].in_time_zone) if permitted_params[:updated_since].present?
          @concepts = apply_paging(@concepts).without_count
          @language = permitted_params[:language].presence || I18n.available_locales.first.to_s

          render json: I18n.with_locale(@language) { sync_api_format(@concepts).to_json }
        end

        def permitted_parameter_keys
          super + [:id, :ids, :updated_since, :index_only, :language]
        end

        private

        def sync_api_format(contents)
          {
            '@graph' => contents.to_sync_data,
            'meta' => api_plain_meta(contents)
          }
        end

        def api_plain_meta(contents)
          {
            hasPrev: !contents.prev_page.nil?,
            hasNext: !contents.next_page.nil?
          }
        end
      end
    end
  end
end
