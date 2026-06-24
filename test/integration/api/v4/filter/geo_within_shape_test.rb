# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class GeoWithinShapeTest < DataCycleCore::V4::Base
          before(:all) do
            @place_inside = create_content('Örtlichkeit', { name: 'PLACE 1', location: RGeo::Geographic.spherical_factory(srid: 4326).point(9.75478205759083, 47.272276443355025) })
            @place_outside = create_content('Örtlichkeit', { name: 'PLACE 2', location: RGeo::Geographic.spherical_factory(srid: 4326).point(9.68076549690997, 47.31632943824184) })
            @polyline = 'oy|_Hy_qz@htMrkJn{MszIacEi`c@urRn}KayBxpU'
            @wkt = 'POLYGON((9.758846327544177 47.33863917786354,9.700506756611873 47.26354837128608,9.75612733107468 47.18730715096737,9.940659638756642 47.21868324432617,9.874341927525677 47.319106886673836,9.758846327544177 47.33863917786354))'
            @geojson = '{"type":"Polygon","coordinates":[[[9.758846328,47.338639178],[9.700506757,47.263548371],[9.756127331,47.187307151],[9.940659639,47.218683244],[9.874341928,47.319106887],[9.758846328,47.338639178]]]}'
            @polyline_line = '{cs_Hc~~{@srLnySqvMibJfcCgfMffUqtD'
            @wkt_line = 'LINESTRING(9.994102997019667 47.28909574960019,9.887456664601274 47.35880433186321,9.944314005123971 47.43425379429462,10.017150746515625 47.41308543503254,10.046197223440373 47.2992850730007)'
            @geojson_line = '{"type":"LineString","coordinates":[[9.994102997,47.28909575],[9.887456665,47.358804332],[9.944314005,47.434253794],[10.017150747,47.413085435],[10.046197223,47.299285073]]}'
          end

          test 'api/v4/things parameter returns all contents' do
            params = { fields: '@id' }
            post api_v4_things_path(params)

            assert_api_count_result(2)
            assert_equal([@place_inside.id, @place_outside.id].to_set, response.parsed_body['@graph'].pluck('@id').to_set)
          end

          test 'api/v4/things parameter filter[:geo][:in][:geoShape][:polygon] polyline' do
            params = { fields: '@id', filter: { geo: { in: { geoShape: { polygon: @polyline } } } } }
            post api_v4_things_path(params)

            assert_api_count_result(1)
            assert_equal([@place_inside.id].to_set, response.parsed_body['@graph'].pluck('@id').to_set)
          end

          test 'api/v4/things parameter filter[:geo][:in][:geoShape][:polygon] wkt' do
            params = { fields: '@id', filter: { geo: { in: { geoShape: { polygon: @wkt } } } } }
            post api_v4_things_path(params)

            assert_api_count_result(1)
            assert_equal([@place_inside.id].to_set, response.parsed_body['@graph'].pluck('@id').to_set)
          end

          test 'api/v4/things parameter filter[:geo][:in][:geoShape][:polygon] geojson' do
            params = { fields: '@id', filter: { geo: { in: { geoShape: { polygon: @geojson } } } } }
            post api_v4_things_path(params)

            assert_api_count_result(1)
            assert_equal([@place_inside.id].to_set, response.parsed_body['@graph'].pluck('@id').to_set)
          end

          test 'api/v4/things parameter filter[:geo][:notIn][:geoShape][:polygon] polyline' do
            params = { fields: '@id', filter: { geo: { notIn: { geoShape: { polygon: @polyline } } } } }
            post api_v4_things_path(params)

            assert_api_count_result(1)
            assert_equal([@place_outside.id].to_set, response.parsed_body['@graph'].pluck('@id').to_set)
          end

          test 'api/v4/things parameter filter[:geo][:notIn][:geoShape][:polygon] wkt' do
            params = { fields: '@id', filter: { geo: { notIn: { geoShape: { polygon: @wkt } } } } }
            post api_v4_things_path(params)

            assert_api_count_result(1)
            assert_equal([@place_outside.id].to_set, response.parsed_body['@graph'].pluck('@id').to_set)
          end

          test 'api/v4/things parameter filter[:geo][:notIn][:geoShape][:polygon] geojson' do
            params = { fields: '@id', filter: { geo: { notIn: { geoShape: { polygon: @geojson } } } } }
            post api_v4_things_path(params)

            assert_api_count_result(1)
            assert_equal([@place_outside.id].to_set, response.parsed_body['@graph'].pluck('@id').to_set)
          end

          test 'api/v4/things parameter filter[:geo][:in][:geoShape][:line] wrong types' do
            params = { fields: '@id', filter: { geo: { in: { geoShape: { line: @wkt } } } } }
            post api_v4_things_path(params)

            assert_predicate(response.parsed_body['errors'], :present?)

            params = { fields: '@id', filter: { geo: { in: { geoShape: { line: @geojson } } } } }
            post api_v4_things_path(params)

            assert_predicate(response.parsed_body['errors'], :present?)
          end

          test 'api/v4/things parameter filter[:geo][:notIn][:geoShape][:polygon] wrong types' do
            params = { fields: '@id', filter: { geo: { in: { geoShape: { polygon: @polyline_line } } } } }
            post api_v4_things_path(params)

            assert_predicate(response.parsed_body['errors'], :present?)

            params = { fields: '@id', filter: { geo: { in: { geoShape: { polygon: @wkt_line } } } } }
            post api_v4_things_path(params)

            assert_predicate(response.parsed_body['errors'], :present?)

            params = { fields: '@id', filter: { geo: { in: { geoShape: { polygon: @geojson_line } } } } }
            post api_v4_things_path(params)

            assert_predicate(response.parsed_body['errors'], :present?)
          end
        end
      end
    end
  end
end
