# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        class ThingGeojsonTest < DataCycleCore::V4::Base
          before(:all) do
            @geojson_feature_state = DataCycleCore.features[:serialize][:serializers][:geojson]
            DataCycleCore.features[:serialize][:serializers][:geojson] = true
            DataCycleCore::Feature::Serialize.reload

            @test_tour = DataCycleCore::DummyDataHelper.create_data('tour')
            tour_data_hash = @test_tour.get_data_hash
            tour_data_hash['universal_classifications'].concat(['Freitag'].map { |m| DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Wochentage', m) })
            @test_tour.set_data_hash(prevent_history: true, data_hash: tour_data_hash)

            @test_poi = DataCycleCore::DummyDataHelper.create_data('poi')
            lat_long = {
              'latitude': 46.123456789,
              'longitude': 14.123456789
            }
            @test_poi.set_data_hash(partial_update: true, prevent_history: true, data_hash: lat_long)
            @test_poi.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@test_poi.longitude, @test_poi.latitude)
            @test_poi.save

            @test_article = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
          end

          after(:all) do
            DataCycleCore.features[:serialize][:serializers][:geojson] = @geojson_feature_state
            DataCycleCore::Feature::Serialize.reload
          end

          test 'validate feature is enabled' do
            assert(DataCycleCore::Feature::Serialize.available_serializers.include?('geojson'))
          end

          test 'geojson of stored tour exists' do
            params = {
              id: @test_tour.id
            }

            post api_v4_thing_path(params), headers: { Accept: 'application/geo+json' }

            assert_response(:success)
            assert_equal('application/geo+json; charset=utf-8', response.content_type)
            geojson_data = RGeo::GeoJSON.decode(response.body)
            assert_equal('Test-TOUR', geojson_data['name'])
          end

          test 'geojson response of geo-object is valid geojson' do
            params = {
              id: @test_tour.id
            }
            post api_v4_thing_path(params), headers: { Accept: 'application/geo+json' }

            assert_response(:success)
            assert_equal('application/geo+json; charset=utf-8', response.content_type)
            geojson_data = response.parsed_body

            assert_equal('Feature', geojson_data.dig('type'))
            assert_kind_of(Hash, geojson_data.dig('geometry'))
            assert_equal('MultiLineString', geojson_data.dig('geometry', 'type'))
            assert_kind_of(Array, geojson_data.dig('geometry', 'coordinates'))
            assert_kind_of(Hash, geojson_data.dig('properties'))
            assert_equal(@test_tour.id, geojson_data.dig('id'))
            assert_equal('Test-TOUR', geojson_data.dig('properties', 'name'))
          end

          test 'stored tour can be found and is correct' do
            params = {
              id: @test_tour.id
            }
            post api_v4_thing_path(params), headers: { Accept: 'application/geo+json' }

            assert_response(:success)
            assert_equal('application/geo+json; charset=utf-8', response.content_type)
            longlat_projection = RGeo::CoordSys::Proj4.new('EPSG:4326')
            factory = RGeo::Cartesian.factory(srid: 4326, proj4: longlat_projection, has_z_coordinate: true, wkt_parser: { support_wkt12: true }, wkt_generator: { convert_case: :upper, tag_format: :wkt12 })
            coder = RGeo::GeoJSON.coder(geo_factory: factory)
            geojson_data = coder.decode(response.body)

            assert_equal('MultiLineString', geojson_data.geometry.geometry_type.type_name)
            assert_equal(@test_tour.id, geojson_data.feature_id)
            assert_equal('Test-TOUR', geojson_data['name'])
          end

          test 'stored poi can be found is correct and contains @id and @type' do
            params = {
              id: @test_poi.id
            }
            post api_v4_thing_path(params), headers: { Accept: 'application/geo+json' }

            assert_response(:success)
            assert_equal('application/geo+json; charset=utf-8', response.content_type)
            geojson_data = RGeo::GeoJSON.decode(response.body)

            assert_equal(@test_poi.location.coordinates.map { |c| c.round(DataCycleCore::Geo::GeojsonRenderer::GEOMETRY_PRECISION) }, geojson_data.geometry.coordinates)
            assert_equal('Point', geojson_data.geometry.geometry_type.type_name)
            assert_equal(@test_poi.id, geojson_data.feature_id)
            assert_equal('Test-POI', geojson_data['name'])
            assert_equal(@test_poi.id, geojson_data['@id'])
            assert_equal(['Place', 'TouristAttraction', 'dcls:POI'], geojson_data['@type'])
          end

          test 'geojson response of geo-object respects includes' do
            params = {
              id: @test_tour.id,
              include: 'dc:classification'
            }
            post api_v4_thing_path(params), headers: { Accept: 'application/geo+json' }

            assert_response(:success)
            assert_equal('application/geo+json; charset=utf-8', response.content_type)
            geojson_data = response.parsed_body

            assert_kind_of(Array, geojson_data.dig('properties', 'dc:classification'))
            assert_not_nil(geojson_data.dig('properties', 'dc:classification').first['@id'])
            assert_not_nil(geojson_data.dig('properties', 'dc:classification').first['dc:path'])
          end

          test 'geojson response of geo-object respects fields' do
            params = {
              id: @test_tour.id,
              include: 'dc:classification',
              fields: '@id,dc:classification.@id'
            }
            post api_v4_thing_path(params), headers: { Accept: 'application/geo+json' }

            assert_response(:success)
            assert_equal('application/geo+json; charset=utf-8', response.content_type)
            geojson_data = response.parsed_body

            assert_nil(geojson_data.dig('properties', 'name'))
            assert_equal(2, geojson_data.dig('properties', 'dc:classification').count)
            assert_not_nil(geojson_data.dig('properties', 'dc:classification').first['@id'])
            assert_nil(geojson_data.dig('properties', 'dc:classification').first['dc:path'])
          end

          test 'geojson response of geo-object respects classification_trees-filter' do
            params = {
              id: @test_tour.id,
              include: 'dc:classification',
              classification_trees: [DataCycleCore::ClassificationTreeLabel.where(name: 'Wochentage').first.id]
            }
            post api_v4_thing_path(params), headers: { Accept: 'application/geo+json' }

            assert_response(:success)
            assert_equal('application/geo+json; charset=utf-8', response.content_type)
            geojson_data = response.parsed_body

            assert_equal(1, geojson_data.dig('properties', 'dc:classification').count)
            assert(geojson_data.dig('properties', 'dc:classification', 0, 'dc:path').include?('Wochentage'))
          end

          test 'geojson of stored article is valid geojson' do
            params = {
              id: @test_article.id
            }
            post api_v4_thing_path(params), headers: { Accept: 'application/geo+json' }

            assert_response(:success)
            assert_equal('application/geo+json; charset=utf-8', response.content_type)

            geojson_data = response.parsed_body

            assert_equal('Feature', geojson_data.dig('type'))
            assert_nil(geojson_data.dig('geometry'))
            assert_nil(geojson_data.dig('properties'))
          end
        end
      end
    end
  end
end
