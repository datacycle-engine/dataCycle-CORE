# frozen_string_literal: true

# simplecov:disable
module DataCycleCore
  module Api
    module V1
      class ClassificationTreesController < Api::V1::ApiBaseController
        include DataCycleCore::ConceptSinceFilterConcern

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
          @concepts = apply_paging(@concepts)
        end

        def permitted_parameter_keys
          super + [:id, :modified_since, :created_since, :deleted_since]
        end
      end
    end
  end
end
# simplecov:enable
