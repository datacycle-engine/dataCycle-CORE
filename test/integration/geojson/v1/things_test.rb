# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Geojson
    module V1
      class ThingTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @routes = Engine.routes
          @current_user = User.find_by(email: 'tester@datacycle.at')

          @test_tour = DataCycleCore::DummyDataHelper.create_data('tour')

          @test_poi = DataCycleCore::DummyDataHelper.create_data('poi')
          lat_long = {
            'latitude': 46.123456789,
            'longitude': 14.123456789
          }
          @test_poi.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long)
          @test_poi.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@test_poi.longitude, @test_poi.latitude)
          @test_poi.save

          # @test_tour2 = DataCycleCore::DummyDataHelper.create_data('tour')

          # @test_tour2.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@test_tour2.longitude, @test_tour2.latitude)
          # @test_tour2.save

          @test_article = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
        end

        setup do
          sign_in(@current_user)
        end

        test 'geojson of stored tour exists' do
          get geojson_v1_content_show_path(id: @test_tour)

          assert_response(:success)
          assert_equal('application/vnd.geo+json; charset=utf-8', response.content_type)
          geojson_data = RGeo::GeoJSON.decode(response.body)
          assert_equal('Test-TOUR', geojson_data['name'])
        end

        test 'geojson of stored tour is valid geojson' do
          get geojson_v1_content_show_path(id: @test_tour)

          assert_response(:success)
          assert_equal('application/vnd.geo+json; charset=utf-8', response.content_type)
          geojson_data = JSON.parse(response.body)

          assert_equal('Feature', geojson_data.dig('type'))
          assert_kind_of(Hash, geojson_data.dig('geometry'))
          assert_equal('MultiLineString', geojson_data.dig('geometry', 'type'))
          assert_kind_of(Array, geojson_data.dig('geometry', 'coordinates'))
          assert_kind_of(Hash, geojson_data.dig('properties'))
          assert_equal(@test_tour.id, geojson_data.dig('id'))
          assert_equal('Test-TOUR', geojson_data.dig('properties', 'name'))
        end

        test 'geojson of stored article is valid geojson' do
          get geojson_v1_content_show_path(id: @test_article)

          assert_response(:success)
          assert_equal('application/vnd.geo+json; charset=utf-8', response.content_type)
          geojson_data = JSON.parse(response.body)

          assert_equal('Feature', geojson_data.dig('type'))
          assert_nil(geojson_data.dig('geometry'))
          assert_kind_of(Hash, geojson_data.dig('properties'))
          assert_equal(@test_article.id, geojson_data.dig('id'))
          assert_equal('TestArtikel', geojson_data.dig('properties', 'name'))
        end

        test 'stored tour can be found and is correct' do
          get geojson_v1_content_show_path(id: @test_tour)

          assert_response(:success)
          assert_equal('application/vnd.geo+json; charset=utf-8', response.content_type)
          longlat_projection = RGeo::CoordSys::Proj4.new('EPSG:4326')
          factory = RGeo::Cartesian.factory(srid: 4326, proj4: longlat_projection, has_z_coordinate: true, wkt_parser: { support_wkt12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 })
          coder = RGeo::GeoJSON.coder(geo_factory: factory)
          geojson_data = coder.decode(response.body)

          assert_equal('MultiLineString', geojson_data.geometry.geometry_type.type_name)
          assert_equal(@test_tour.id, geojson_data.feature_id)
          assert_equal('Test-TOUR', geojson_data['name'])
        end

        test 'stored poi can be found and is correct' do
          get geojson_v1_content_show_path(id: @test_poi)

          assert_response(:success)
          assert_equal('application/vnd.geo+json; charset=utf-8', response.content_type)
          geojson_data = RGeo::GeoJSON.decode(response.body)

          assert_equal(@test_poi.location.coordinates.map { |c| c.round(DataCycleCore::Content::Extensions::Geojson::GEOMETRY_PRECISION) }, geojson_data.geometry.coordinates)
          assert_equal('Point', geojson_data.geometry.geometry_type.type_name)
          assert_equal(@test_poi.id, geojson_data.feature_id)
          assert_equal('Test-POI', geojson_data['name'])
        end

        # TODO: following list:
        # test languages output (watch_list + stored_filter)
        # test Model
      end
    end
  end
end
