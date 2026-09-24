# frozen_string_literal: true

# simplecov:disable
module DataCycleCore
  module Api
    module V2
      class ClassificationTreesController < Api::V2::ApiBaseController
        include DataCycleCore::ConceptSinceFilterConcern

        before_action :prepare_url_parameters

        ALLOWED_INCLUDE_PARAMETERS = ['linked', 'translations'].freeze
        ALLOWED_MODE_PARAMETERS = ['compact', 'minimal'].freeze

        def index
          @concept_schemes = apply_since_filters(concept_scheme_scope(since_params), since_params)
          @concept_schemes = apply_paging(@concept_schemes)
        end

        def show
          @concept_scheme = ConceptScheme.find(permitted_params[:id])
        end

        def classifications
          @concept_scheme = ConceptScheme.find_including_history(permitted_params[:id])
          @concepts = apply_since_filters(concept_scope(@concept_scheme, since_params), since_params)
          @concepts = apply_paging(@concepts.order(:internal_name))
        end

        def prepare_url_parameters
          @url_parameters = permitted_params.except('format')
          @include_parameters = (permitted_params[:include]&.split(',') || []).select { |v| ALLOWED_INCLUDE_PARAMETERS.include?(v) }.sort
          @mode_parameters = (permitted_params[:mode]&.split(',') || []).select { |v| ALLOWED_MODE_PARAMETERS.include?(v) }.sort
          @language = permitted_params[:language] || I18n.default_locale.to_s
          @api_subversion = permitted_params[:api_subversion] if DataCycleCore.main_config.dig(:api, :v2, :subversions)&.include?(permitted_params[:api_subversion])
          @api_version = 2
        end

        def permitted_parameter_keys
          super + [:id, :include, :mode, :language, { filter: [:modified_since, :created_since, :deleted_since] }]
        end
      end
    end
  end
end
# simplecov:enable
