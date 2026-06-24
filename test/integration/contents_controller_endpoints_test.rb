# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentsControllerEndpointsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @current_user = User.find_by(email: 'admin@datacycle.at')
      @artikel = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'EndpointsArtikel' })
      @poi = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: {
          name: 'EndpointsPOI',
          location: RGeo::Geographic.spherical_factory(srid: 4326).point(13.3, 46.6)
        }
      )
      @related_artikel = DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: { name: 'EndpointsRelatedArtikel', content_location: [@poi.id] }
      )
      image = upload_image('test_rgb.jpeg')
      @bild = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'EndpointsBild', asset: image.id })
    end

    setup do
      sign_in(@current_user)
    end

    test 'asset redirects to content url of image' do
      get "/things/#{@bild.id}/asset/content"

      assert_response :redirect
      assert_includes response.location, 'test_rgb.jpeg'
    end

    test 'asset responds with not_found for content without image' do
      get "/things/#{@artikel.id}/asset/thumb"

      assert_response :not_found
    end

    test 'select_search returns matching contents as select options' do
      get select_search_things_path, params: { q: 'EndpointsArtikel', template_name: 'Artikel', max: '10' }

      assert_response :success
      assert_equal 'application/json', response.media_type
      assert_includes response.body, @artikel.id
    end

    test 'attribute_value returns requested attribute values' do
      key = 'thing[translations][de][name]'

      post attribute_value_thing_path(@artikel), xhr: true, params: { keys: [key], locale: 'de' }

      assert_response :success
      assert_equal @artikel.name, response.parsed_body[key]
    end

    test 'attribute_default_value returns default values as form data' do
      post attribute_default_value_things_path, xhr: true, params: { template_name: 'Artikel', keys: ['data_type'], locale: 'de' }

      assert_response :success

      default_values = response.parsed_body['data_type']

      assert_predicate default_values, :present?
      assert_includes DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('Inhaltstypen', 'Artikel'), default_values.first['value']
    end

    test 'content_score returns calculated score' do
      post content_score_things_path, xhr: true, params: {
        template_name: 'Artikel',
        attribute_key: 'name',
        locale: 'de',
        thing: { translations: { de: { name: 'ContentScoreArtikel' } } }
      }

      assert_response :success
      assert response.parsed_body.key?('value')
    end

    test 'geojson_for_map_editor returns empty feature collection without params' do
      get geojson_for_map_editor_things_path

      assert_response :success
      assert_equal 'application/vnd.geo+json', response.media_type
      assert_equal({ type: 'FeatureCollection', features: [] }.to_json, response.body)
    end

    test 'geojson_for_map_editor returns geojson for filtered contents' do
      post geojson_for_map_editor_things_path, params: { template_name: 'POI', ids: [@poi.id] }

      assert_response :success
      assert_equal 'application/geo+json', response.media_type
      assert_includes response.body, @poi.id
    end

    test 'elevation_profile returns error for content without geo data' do
      post elevation_profile_thing_path(@artikel), xhr: true

      assert_response :not_found
      assert_predicate response.parsed_body['error'], :present?
    end

    test 'load_more_related renders related contents' do
      get load_more_related_thing_path(@poi), xhr: true, params: { page: 1, locale: 'de' }, headers: { referer: thing_path(@poi) }

      assert_response :success
      assert_includes response.body, 'EndpointsRelatedArtikel'
    end

    test 'load_more_duplicates renders duplicates list' do
      get load_more_duplicates_thing_path(@artikel), xhr: true, params: { prefix: 'duplicates-prefix' }, headers: { referer: thing_path(@artikel) }

      assert_response :success
      assert_equal 'text/javascript', response.media_type
    end
  end
end
