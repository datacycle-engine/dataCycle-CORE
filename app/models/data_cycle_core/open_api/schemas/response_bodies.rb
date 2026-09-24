# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Schemas
      # Inline response-body schemas for the non-envelope delivery endpoints
      # (timeseries, statistics, elevation profile) and the concept-facet
      # collection. Defined once here and inlined into the relevant path
      # operations (Paths::Delivery / Contents / ExternalSources) so the OpenAPI
      # viewer shows the real shape instead of a bare `object`. Kept out of the
      # path modules to keep those focused on routing and under the size limit.
      module ResponseBodies
        module_function

        # Timeseries body (Paths::Contents thing-scoped + Paths::Delivery
        # endpoint-scoped): `data` is [[timestamp, value], …] (dataFormat=array,
        # the default) or [{x, y}, …] (dataFormat=object); `meta.scale_x` carries
        # the bucket unit for grouped (groupBy) requests. Built in SQL by
        # ApiRenderer::TimeseriesRenderer, so `value` is a plain number.
        def timeseries_data
          chart_series('TimeseriesData', { 'type' => 'number' }, meta_key: 'scale_x')
        end

        # Statistics body: same chart shape as the timeseries, built by
        # ApiRenderer::StatisticsRenderer. `value` is the content id (uuid) for
        # ungrouped requests or a count (integer) for grouped ones; the bucket
        # unit is exposed as `meta.scaleX` (camelCase, unlike the timeseries).
        def statistics_data
          chart_series('StatisticsData', { 'oneOf' => [{ 'type' => 'string', 'format' => 'uuid' }, { 'type' => 'integer' }] }, meta_key: 'scaleX')
        end

        # Shared { data, meta } chart shape for the timeseries / statistics
        # renderers. `data` items are either a [timestamp, value] tuple or an
        # { x, y } object; `meta` (only present when grouped) exposes the bucket
        # unit under meta_key.
        def chart_series(title, value_schema, meta_key:)
          ts = { 'type' => 'string', 'format' => 'date-time' }
          {
            'type' => 'object',
            'title' => title,
            'properties' => {
              'data' => {
                'type' => 'array',
                'items' => {
                  'oneOf' => [
                    { 'type' => 'array', 'prefixItems' => [ts, value_schema], 'minItems' => 2, 'maxItems' => 2 },
                    { 'type' => 'object', 'properties' => { 'x' => ts, 'y' => value_schema } }
                  ]
                }
              },
              'meta' => { 'type' => 'object', 'properties' => { meta_key => { 'type' => 'string' } } }
            }
          }
        end

        # Elevation-profile body (ApiRenderer::ElevationProfileRenderer): `data`
        # items are either a [distance, elevation, [lon, lat]] tuple or an
        # { x, y, coordinates } object (all metres); `meta` fixes the axis units.
        def elevation_profile
          number = { 'type' => 'number' }
          lon_lat = { 'type' => 'array', 'prefixItems' => [number, number], 'minItems' => 2, 'maxItems' => 2 }
          {
            'type' => 'object',
            'title' => 'ElevationProfile',
            'properties' => {
              'data' => {
                'type' => 'array',
                'items' => {
                  'oneOf' => [
                    { 'type' => 'array', 'prefixItems' => [number, number, lon_lat], 'minItems' => 3, 'maxItems' => 3 },
                    { 'type' => 'object', 'properties' => { 'x' => number, 'y' => number, 'coordinates' => lon_lat } }
                  ]
                }
              },
              'meta' => { 'type' => 'object', 'properties' => { 'scaleX' => { 'type' => 'string', 'example' => 'm' }, 'scaleY' => { 'type' => 'string', 'example' => 'm' } } }
            }
          }
        end

        # Facet body (Paths::Delivery facets + Feratel location facets in
        # Paths::ExternalSources): a JSON-LD envelope whose `@graph` holds the
        # shared Concept schema augmented with the two facet-count fields; `meta`
        # / `links` carry paging (absent when a page limit is set).
        def facet_collection
          {
            'type' => 'object',
            'title' => 'FacetCollection',
            'properties' => {
              '@context' => { 'type' => 'object', 'additionalProperties' => true },
              '@graph' => {
                'type' => 'array',
                'items' => {
                  'allOf' => [
                    { '$ref' => '#/components/schemas/Concept' },
                    { 'type' => 'object', 'properties' => { 'dc:thingCountWithSubtree' => { 'type' => 'integer' }, 'dc:thingCountWithoutSubtree' => { 'type' => 'integer' } } }
                  ]
                }
              },
              # $ref to the registered envelope building blocks rather than a second spelling-out:
              # meta/links are the same sections here as in JsonLdEnvelope (built by
              # ThingRendererV4.api_plain_meta/_links). Spelled out, they carried its fields a
              # second time, and a change to the envelope would have left the facets response
              # silently on the old shape.
              'meta' => { '$ref' => '#/components/schemas/EnvelopeMeta' },
              'links' => { '$ref' => '#/components/schemas/EnvelopeLinks' }
            }
          }
        end

        # Facets by external system. Deliberately NOT facet_collection: its @graph items are
        # Concepts with the two subtree counts, while this endpoint groups by
        # +things.external_source_id+ and returns one dc:ExternalSystem per source with a single
        # count -- an external system has no subtree, so both count keys would be a false promise.
        # +@id+ is the system's identifier (not a UUID), matching the view.
        def external_system_facet_collection
          {
            'type' => 'object',
            'title' => 'ExternalSystemFacetCollection',
            'properties' => {
              '@context' => { 'type' => 'object', 'additionalProperties' => true },
              '@graph' => {
                'type' => 'array',
                'items' => {
                  'type' => 'object',
                  'properties' => {
                    '@id' => { 'type' => 'string' },
                    '@type' => { 'type' => 'string' },
                    'name' => { 'type' => 'string' },
                    'dc:thingCount' => { 'type' => 'integer' }
                  }
                }
              },
              'meta' => { 'type' => 'object', 'properties' => { 'total' => { 'type' => 'integer' } } }
            }
          }
        end

        # Duplicate candidates of one content (Api::V4::DuplicatesController#render_duplicates).
        # Not an envelope: the entries sit under +dc:duplicates+ and are neither a @graph nor
        # linkable, so there is no @context/links section. One entry per duplicate content, with
        # the highest score of the pair and every method that found it. +meta+ is absent for
        # section[meta]=0.
        def duplicate_collection
          {
            'type' => 'object',
            'title' => 'DuplicateCollection',
            'properties' => {
              '@id' => { 'type' => 'string', 'format' => 'uuid' },
              'meta' => { 'type' => 'object', 'properties' => { 'total' => { 'type' => 'integer' }, 'pages' => { 'type' => 'integer' } } },
              'dc:duplicates' => {
                'type' => 'array',
                'items' => {
                  'type' => 'object',
                  'properties' => {
                    '@id' => { 'type' => 'string', 'format' => 'uuid' },
                    '@type' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
                    'name' => { 'type' => 'string' },
                    'dct:modified' => { 'type' => 'string', 'format' => 'date-time' },
                    'dc:score' => { 'type' => 'number' },
                    'dc:duplicateMethod' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
                    'dc:falsePositive' => { 'type' => 'boolean' }
                  }
                }
              }
            }
          }
        end

        # External connections of one content after a change
        # (Api::V4::ExternalConnectionsController#render_connections). The entries are the same
        # PropertyValues the delivery API publishes under +identifier+, hence the $ref -- written
        # out a second time it would drift from the shared component.
        def external_connection_collection
          {
            'type' => 'object',
            'title' => 'ExternalConnectionCollection',
            'properties' => {
              '@id' => { 'type' => 'string', 'format' => 'uuid' },
              'identifier' => { 'type' => 'array', 'items' => { '$ref' => '#/components/schemas/PropertyValue' } }
            }
          }
        end
      end
    end
  end
end
