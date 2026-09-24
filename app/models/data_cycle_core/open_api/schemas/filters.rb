# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Schemas
      # The v4 content filter as OpenAPI 3.1 schemas.
      #
      # Source of truth: docs/api/contents/specification.md.erb (mirrored by
      # ApiService#apply_filters). The filter is recursive — `graph`, `linked`
      # and `union` nest the full filter again — so `Filter` is a named,
      # self-referencing component. GET requests pass it as bracket parameters
      # (deepObject), POST requests as the JSON body (`ContentQuery`).
      #
      # Split across Filters::Predicates (leaf/predicate sub-shapes),
      # Filters::Parameters (the GET `filter` query parameter + examples) and
      # Filters::Body (the POST request bodies) for readability; all three are
      # extended in so their methods are plain Filters.* module methods, same
      # as Localizable's `t`.
      module Filters
        module_function

        extend DataCycleCore::OpenApi::Localizable
        extend DataCycleCore::OpenApi::Schemas::Filters::Predicates
        extend DataCycleCore::OpenApi::Schemas::Filters::Parameters
        extend DataCycleCore::OpenApi::Schemas::Filters::Body

        FILTER_REF = '#/components/schemas/Filter'

        # @return [Hash{String=>Hash}] schemas for components/schemas.
        #
        # The recurring filter sub-shapes are registered as named components so
        # Swagger UI renders them as compact, collapsed `$ref` models instead of
        # repeating the same deep inline object tree (IdFilter alone is reused 6×).
        def schemas
          {
            'Filter' => filter,
            'ContentQuery' => filter_body,
            'DeliveryParams' => delivery_params,
            'IdFilter' => id_in_not_in.merge('title' => 'IdFilter'),
            'AttributeCondition' => attribute_condition.merge('title' => 'AttributeCondition'),
            'ScheduleFilter' => schedule_filter.merge('title' => 'ScheduleFilter'),
            'ClassificationFilter' => classification_filter.merge('title' => 'ClassificationFilter'),
            'GeoFilter' => geo_filter.merge('title' => 'GeoFilter'),
            'SearchFilter' => search_filter.merge('title' => 'SearchFilter'),
            'DuplicateCandidateFilter' => duplicate_candidate_filter.merge('title' => 'DuplicateCandidateFilter')
          }
        end

        # A `$ref` to a named component under components/schemas.
        def ref(name)
          { '$ref' => "#/components/schemas/#{name}" }
        end

        # The recursive content filter object. Properties are ordered by how often
        # developers reach for them (search/classification/attribute/geo first,
        # niche id-filters next, recursive/deprecated last) so the most useful
        # filters surface at the top of Swagger UI.
        def filter
          {
            'type' => 'object',
            'title' => 'Filter',
            'properties' => {
              'search' => ref('SearchFilter'),
              'q' => ref('SearchFilter'),
              'dc:classification' => ref('ClassificationFilter'),
              'classifications' => ref('ClassificationFilter'),
              'attribute' => {
                'type' => 'object',
                'title' => 'AttributeFilter',
                'description' => t('filter.attribute'),
                'additionalProperties' => ref('AttributeCondition')
              },
              'geo' => ref('GeoFilter'),
              'schedule' => ref('ScheduleFilter'),
              'contentId' => ref('IdFilter'),
              'creator' => ref('IdFilter'),
              'classificationTreeId' => ref('IdFilter'),
              'watchListId' => ref('IdFilter'),
              'filterId' => ref('IdFilter'),
              'endpointId' => ref('IdFilter'),
              'externalSystem' => ref('IdFilter'),
              'duplicateCandidates' => ref('DuplicateCandidateFilter'),
              'graph' => nested_filter_map(t('filter.graph')),
              'union' => {
                'type' => 'array',
                'description' => t('filter.union'),
                'items' => { '$ref' => FILTER_REF }
              },
              'linked' => nested_filter_map(t('filter.linked')).merge('deprecated' => true)
            }
          }
        end
      end
    end
  end
end
