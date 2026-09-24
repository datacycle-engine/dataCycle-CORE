# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Schemas
      module Filters
        # Leaf/predicate sub-shapes shared across the filter tree (id lists,
        # attribute bounds, schedule/classification/geo/search predicates) plus
        # a couple of small reusable primitives. Extended into Filters so its
        # methods are available as Filters.* module methods (mirrors Localizable).
        module Predicates
          # Reusable { in: bound, notIn: bound } wrapper shape, optionally with
          # extra sibling properties (e.g. geo_filter's withGeometry).
          def in_not_in(bound, **extra_properties)
            {
              'type' => 'object',
              'properties' => {
                'in' => bound,
                'notIn' => bound,
                **extra_properties
              }
            }
          end

          # { in: [String], notIn: [String] } — the id-list filter shape.
          def id_in_not_in
            in_not_in(string_array)
          end

          # An attribute condition: { in: bound, notIn: bound }.
          def attribute_condition
            in_not_in(attribute_bound)
          end

          # The comparison bound of an attribute filter.
          def attribute_bound
            {
              'type' => 'object',
              'properties' => {
                'max' => number_or_string,
                'min' => number_or_string,
                'equals' => number_or_string,
                'like' => { 'type' => 'string' },
                'bool' => { 'type' => 'boolean' }
              }
            }
          end

          # schedule filter: { in: {min,max}, all: { in: {min,max} } }.
          def schedule_filter
            min_max = {
              'type' => 'object',
              'properties' => {
                'min' => { 'type' => 'string', 'description' => t('filter.min_max') },
                'max' => { 'type' => 'string', 'description' => t('filter.min_max') }
              }
            }
            {
              'type' => 'object',
              'properties' => {
                'in' => min_max,
                'all' => {
                  'type' => 'object',
                  'description' => t('filter.schedule_all'),
                  'properties' => { 'in' => min_max }
                }
              }
            }
          end

          # dc:classification / classifications filter: { in: subtree, notIn: subtree }.
          def classification_filter
            subtree = {
              'type' => 'object',
              'properties' => {
                'withSubtree' => string_array,
                'withoutSubtree' => string_array
              }
            }
            in_not_in(subtree)
          end

          # geo filter: { in: geoInner, notIn: geoInner, withGeometry: Boolean }.
          def geo_filter
            in_not_in(geo_inner, 'withGeometry' => { 'type' => 'boolean' })
          end

          # The inner geo predicate (box / perimeter / shapes / geoShape).
          def geo_inner
            {
              'type' => 'object',
              'properties' => {
                'box' => { 'type' => 'array', 'items' => { 'type' => 'number' }, 'description' => t('filter.geo_box') },
                'perimeter' => { 'type' => 'array', 'items' => { 'type' => 'number' }, 'description' => t('filter.geo_perimeter') },
                'shapes' => string_array,
                'geoShape' => {
                  'type' => 'object',
                  'properties' => {
                    'polygon' => { 'type' => 'string', 'description' => t('filter.geo_shape') },
                    'line' => { 'type' => 'string', 'description' => t('filter.geo_shape') }
                  }
                }
              }
            }
          end

          # search / q: either a plain string or { value, fields }.
          def search_filter
            {
              'oneOf' => [
                { 'type' => 'string' },
                {
                  'type' => 'object',
                  'properties' => {
                    'value' => { 'type' => 'string' },
                    'fields' => { 'type' => 'string', 'description' => t('filter.search_fields') }
                  }
                }
              ]
            }
          end

          # duplicateCandidates: { exists, minScore, maxScore, method }, mirroring
          # BaseContract::DUPLICATE_CANDIDATE_FILTER. `exists` is the only key that
          # can also EXCLUDE contents (false = only those without candidates); the
          # score bounds and the method narrow the candidates that count.
          def duplicate_candidate_filter
            {
              'type' => 'object',
              'properties' => {
                'exists' => { 'type' => 'boolean', 'description' => t('filter.duplicate_candidates_exists') },
                'minScore' => { 'type' => 'number', 'description' => t('filter.duplicate_candidates_min_score') },
                'maxScore' => { 'type' => 'number', 'description' => t('filter.duplicate_candidates_max_score') },
                'method' => { 'type' => 'string', 'description' => t('filter.duplicate_candidates_method') }
              }
            }
          end

          # An object whose values are nested filters (graph / linked).
          def nested_filter_map(description)
            {
              'type' => 'object',
              'description' => description,
              'additionalProperties' => { '$ref' => DataCycleCore::OpenApi::Schemas::Filters::FILTER_REF }
            }
          end

          # Reusable { type: array, items: string }. Carries the AND/OR gotcha:
          # several entries = AND, one comma-separated entry = OR.
          def string_array
            { 'type' => 'array', 'items' => { 'type' => 'string' }, 'description' => t('filter.string_list') }
          end

          # Reusable oneOf [number, string] (numbers, dates or plain strings).
          def number_or_string
            { 'oneOf' => [{ 'type' => 'number' }, { 'type' => 'string' }] }
          end
        end
      end
    end
  end
end
