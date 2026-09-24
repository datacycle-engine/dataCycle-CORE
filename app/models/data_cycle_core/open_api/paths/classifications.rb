# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for the v4 SKOS classification endpoints
      # (config/routes.rb → classification_trees controller):
      #   /concept_schemes                                  (index)
      #   /concept_schemes/:id                              (show)
      #   /concept_schemes/:id/concepts(/:classification_id)(classifications)
      # All available as GET and POST.
      module Classifications
        module_function

        TAGS = ['Classifications'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/concept_schemes' => concept_schemes,
            '/concept_schemes/{id}' => concept_scheme,
            '/concept_schemes/{id}/concepts' => concepts,
            '/concept_schemes/{id}/concepts/{classification_id}' => concept
          }
        end

        # GET/POST /concept_schemes — list of visible concept schemes.
        def concept_schemes
          Common.read_path_item(
            operation_id: 'ConceptSchemes',
            summary: t('paths.classifications.concept_schemes_summary'),
            tags: TAGS,
            parameters: Common.list_parameters + [search_parameter(t('paths.classifications.concept_schemes_search'))],
            responses: {
              '200' => Common.envelope_response(t('paths.classifications.concept_schemes_response'))
            }.merge(Common.error_responses)
          )
        end

        # `search` query parameter -- real ClassificationTreeLabel#search /
        # ClassificationTreesController#permitted_filter_parameters full-text
        # search, not covered by Common.list_parameters.
        def search_parameter(description)
          DataCycleCore::OpenApi::Components::Parameters.query_string('search', description)
        end

        # GET/POST /concept_schemes/{id} — a single concept scheme.
        def concept_scheme
          Common.read_path_item(
            operation_id: 'ConceptScheme',
            summary: t('paths.classifications.concept_scheme_summary'),
            tags: TAGS,
            parameters: [Common.id_path_param('id', t('paths.classifications.concept_scheme_id'))] + Common.single_parameters,
            responses: {
              '200' => Common.envelope_response(t('paths.classifications.concept_scheme_response'))
            }.merge(Common.error_responses)
          )
        end

        # GET/POST /concept_schemes/{id}/concepts — concepts of a scheme.
        def concepts
          Common.read_path_item(
            operation_id: 'Concepts',
            summary: t('paths.classifications.concepts_summary'),
            tags: TAGS,
            parameters: [Common.id_path_param('id', t('paths.classifications.concept_scheme_id'))] + Common.list_parameters + [search_parameter(t('paths.classifications.concepts_search'))],
            responses: {
              '200' => Common.envelope_response(t('paths.classifications.concepts_response'))
            }.merge(Common.error_responses)
          )
        end

        # GET/POST /concept_schemes/{id}/concepts/{classification_id} — one concept subtree.
        def concept
          Common.read_path_item(
            operation_id: 'ConceptSubtree',
            summary: t('paths.classifications.concept_summary'),
            tags: TAGS,
            parameters: [
              Common.id_path_param('id', t('paths.classifications.concept_scheme_id')),
              Common.id_path_param('classification_id', t('paths.classifications.concept_classification_id'))
            ] + Common.list_parameters,
            responses: {
              '200' => Common.envelope_response(t('paths.classifications.concepts_response'))
            }.merge(Common.error_responses)
          )
        end
      end
    end
  end
end
