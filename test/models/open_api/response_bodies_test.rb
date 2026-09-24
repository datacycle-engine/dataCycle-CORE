# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module OpenApi
    # Guards the concrete response-body schemas (Schemas::ResponseBodies) and the
    # single-source wiring of them into the path operations. Two things are
    # asserted here:
    #   1. the shapes themselves mirror what the ApiRenderers actually emit
    #      (data/meta layout, value types, the subtle scale_x vs scaleX naming);
    #   2. every path module that documents one of these bodies pulls it straight
    #      from ResponseBodies (no per-module copy, no reaching through another
    #      Paths module) — so the schema can never drift between endpoints.
    # Pure hash builders, so no DB is needed; the path builders call t(), hence
    # the I18n.with_locale wrappers.
    class ResponseBodiesTest < DataCycleCore::TestCases::ActiveSupportTestCase
      RB = DataCycleCore::OpenApi::Schemas::ResponseBodies

      # The JSON body schema documented for the given response code of an
      # operation object (operations carry an 'operationId').
      def json_schema(operation, code)
        operation.dig('responses', code, 'content', 'application/json', 'schema')
      end

      # ---- ResponseBodies shapes -----------------------------------------

      test 'timeseries_data is the { data, meta } chart shape with numeric values' do
        schema = RB.timeseries_data

        assert_equal 'TimeseriesData', schema['title']
        assert_equal 'object', schema['type']

        item = schema.dig('properties', 'data', 'items')
        tuple, object = item['oneOf']

        assert_equal 'number', tuple['prefixItems'].last['type'], 'timeseries value is a plain number'
        assert_equal [2, 2], [tuple['minItems'], tuple['maxItems']], '[timestamp, value] is a fixed 2-tuple'
        assert_equal 'date-time', tuple['prefixItems'].first['format']
        assert_equal ['x', 'y'], object['properties'].keys, 'object form exposes x/y'
      end

      test 'statistics_data value is a uuid-or-integer and carries the camelCase meta key' do
        schema = RB.statistics_data

        assert_equal 'StatisticsData', schema['title']

        value = schema.dig('properties', 'data', 'items', 'oneOf').first['prefixItems'].last

        assert_equal 2, value['oneOf'].size, 'value is uuid (ungrouped) OR integer count (grouped)'
        assert_includes value['oneOf'], { 'type' => 'string', 'format' => 'uuid' }
        assert_includes value['oneOf'], { 'type' => 'integer' }
      end

      # The two chart bodies are built from the same helper but must NOT be
      # interchangeable: the timeseries renderer emits meta.scale_x (snake_case),
      # the statistics renderer meta.scaleX (camelCase). A regression that unifies
      # the key would silently misdocument one of them.
      test 'timeseries and statistics expose their bucket-unit under different meta keys' do
        assert_equal ['scale_x'], RB.timeseries_data.dig('properties', 'meta', 'properties').keys
        assert_equal ['scaleX'], RB.statistics_data.dig('properties', 'meta', 'properties').keys
      end

      test 'elevation_profile tuple is [distance, elevation, [lon, lat]] with fixed axis units' do
        schema = RB.elevation_profile

        assert_equal 'ElevationProfile', schema['title']

        tuple = schema.dig('properties', 'data', 'items', 'oneOf').first

        assert_equal [3, 3], [tuple['minItems'], tuple['maxItems']], 'tuple is distance, elevation, coordinates'
        coordinates = tuple['prefixItems'].last

        assert_equal [2, 2], [coordinates['minItems'], coordinates['maxItems']], '[lon, lat] is a fixed 2-tuple'
        assert_equal 'm', schema.dig('properties', 'meta', 'properties', 'scaleX', 'example')
        assert_equal 'm', schema.dig('properties', 'meta', 'properties', 'scaleY', 'example')
      end

      test 'facet_collection is a JSON-LD graph of Concept augmented with facet counts' do
        schema = RB.facet_collection

        assert_equal 'FacetCollection', schema['title']

        graph_item = schema.dig('properties', '@graph', 'items')
        concept_ref, counts = graph_item['allOf']

        assert_equal '#/components/schemas/Concept', concept_ref['$ref'], 'reuses the shared Concept schema'
        assert_equal ['dc:thingCountWithSubtree', 'dc:thingCountWithoutSubtree'], counts['properties'].keys
        # meta/links by $ref to the registered envelope building blocks rather than a second
        # spelling-out of their fields: they are the same sections as in JsonLdEnvelope, and
        # spelled out the facets response would silently go stale when the envelope changes.
        assert_equal '#/components/schemas/EnvelopeMeta', schema.dig('properties', 'meta', '$ref')
        assert_equal '#/components/schemas/EnvelopeLinks', schema.dig('properties', 'links', '$ref')
      end

      # ---- single-source wiring into the path operations -----------------

      # The timeseries body is documented on both the thing-scoped (Contents) and
      # the endpoint-scoped (Delivery) operations. Both must pull the very same
      # schema from ResponseBodies — not a copy, and Contents must not reach into
      # Delivery for it (the refactor that removed the Delivery.*_schema facade).
      test 'thing- and endpoint-scoped timeseries share the single ResponseBodies schema' do
        I18n.with_locale(:en) do
          thing = json_schema(Paths::Contents.thing_timeseries['get'], '200')
          endpoint = json_schema(Paths::Delivery.endpoint_timeseries['get'], '200')

          assert_equal RB.timeseries_data, thing
          assert_equal RB.timeseries_data, endpoint
        end
      end

      test 'statistics and elevation operations document their ResponseBodies schema' do
        I18n.with_locale(:en) do
          assert_equal RB.statistics_data, json_schema(Paths::Delivery.statistics['get'], '200')
          assert_equal RB.elevation_profile, json_schema(Paths::Delivery.elevation_profile['get'], '200')
        end
      end

      # The facet body is shared by the delivery facets and the Feratel location
      # facets in ExternalSources; the latter used to reach into Delivery for it.
      test 'delivery facets and Feratel location facets share the single facet schema' do
        I18n.with_locale(:en) do
          delivery = json_schema(Paths::Delivery.facets['get'], '200')
          feratel = json_schema(Paths::ExternalSources.facets_locations['get'], '200')

          assert_equal RB.facet_collection, delivery
          assert_equal RB.facet_collection, feratel
        end
      end

      # None of the endpoints that gained a concrete body may fall back to the
      # bare generic { 'type' => 'object' } placeholder any more.
      test 'documented delivery bodies are concrete, not the generic object placeholder' do
        I18n.with_locale(:en) do
          [
            json_schema(Paths::Delivery.facets['get'], '200'),
            json_schema(Paths::Delivery.statistics['get'], '200'),
            json_schema(Paths::Delivery.endpoint_timeseries['get'], '200'),
            json_schema(Paths::Delivery.elevation_profile['get'], '200')
          ].each do |schema|
            assert_not_equal({ 'type' => 'object' }, schema)
            assert schema.key?('title'), "expected a concrete titled schema, got #{schema.inspect}"
          end
        end
      end

      # ---- collections item operations: 204, no body ---------------------

      # add_item/remove_item hit v4 actions with no template, so Rails'
      # ImplicitRender answers 204 No Content — the operation must document that,
      # not a 200 with a body.
      test 'collection add_item/remove_item document 204 No Content without a body' do
        I18n.with_locale(:en) do
          [Paths::Collections.add_item(with_thing_id: false), Paths::Collections.remove_item(with_thing_id: false)].each do |operation|
            assert operation.dig('responses', '204'), 'must document 204 No Content'
            assert_nil operation.dig('responses', '200'), 'must not document a 200 body'
            assert_nil operation.dig('responses', '204', 'content'), '204 carries no body'
          end
        end
      end
    end
  end
end
