# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ObjectBrowserTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @biografy = DataCycleCore::TestPreparations.create_content(template_name: 'Biografie', data_hash: { name: 'TestBiografie' })
      @person = DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: { given_name: 'Der', family_name: 'Tester' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'get all persons in object_browser' do
      post object_browser_show_path, xhr: true, as: :json, params: {
        append: false,
        definition: @biografy.schema.dig('properties', 'about'),
        editable: true,
        excluded: [],
        key: 'thing[datahash][about]',
        locale: 'de',
        objects: [],
        options: {
          readonly: false
        },
        page: 1,
        per: 25,
        type: @biografy.schema_type,
        template_name: @biografy.template_name,
        search: @person.family_name
      }, headers: {
        referer: thing_path(@biografy)
      }

      assert_response :success
      assert_includes @response.body, @person.title
    end

    test 'copy persons in split view' do
      post object_browser_find_path, xhr: true, as: :json, params: {
        class: @person.class.name,
        template_name: @person.template_name,
        definition: @biografy.schema.dig('properties', 'about'),
        editable: true,
        external: false,
        key: 'thing[datahash][about]',
        ids: [
          @person.id
        ],
        locale: 'de',
        objects: [],
        options: {
          readonly: false
        },
        type: @person.schema_type
      }, headers: {
        referer: edit_thing_path(@biografy)
      }

      assert_response :success
      assert_includes @response.body, @person.title
    end

    test 'copy persons in split view with external id' do
      external_key = 'xxx-xxx-xxx'
      @person.update(external_key:)

      post object_browser_find_path, xhr: true, as: :json, params: {
        class: @person.class.name,
        template_name: @person.template_name,
        definition: @biografy.schema.dig('properties', 'about'),
        editable: true,
        external: true,
        key: 'thing[datahash][about]',
        ids: [
          external_key
        ],
        locale: 'de',
        objects: [],
        options: {
          readonly: false
        },
        type: @person.schema_type
      }, headers: {
        referer: edit_thing_path(@biografy)
      }

      assert_response :success
      assert_includes @response.body, @person.title
    end

    test 'show person details in object browser' do
      post object_browser_details_path, xhr: true, as: :json, params: {
        class: @person.class.name,
        definition: @biografy.schema.dig('properties', 'about'),
        key: 'thing[datahash][about]',
        id: @person.id,
        locale: 'de',
        options: {
          readonly: false
        },
        type: @person.schema_type
      }, headers: {
        referer: edit_thing_path(@biografy)
      }

      assert_response :success
      assert_includes @response.body, @person.title
    end

    test 'limited_by_linked only offers contents linked to the current content' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      linked_poi = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'OB limited linked POI', location: factory.point(11.0, 47.0) })
      other_poi = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'OB limited unlinked POI', location: factory.point(11.1, 47.1) })
      linking = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'OB limited linking article', content_location: [linked_poi.id] })

      post object_browser_show_path, xhr: true, as: :json, params: {
        content_id: linking.id,
        definition: {
          type: 'linked',
          template_name: 'POI',
          ui: { edit: { options: { limited_by_linked: 'content_location' } } }
        },
        key: 'thing[datahash][content_location]',
        locale: 'de',
        page: 1,
        per: 25
      }, headers: {
        referer: edit_thing_path(linking)
      }

      assert_response :success
      assert_includes @response.body, linked_poi.title
      assert_not_includes @response.body, other_poi.title
    end

    test 'limited_by_linked restricts the result count to the linked set' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      poi_a = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'OB count POI a', location: factory.point(11.0, 47.0) })
      poi_b = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'OB count POI b', location: factory.point(11.1, 47.1) })
      DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'OB count POI c unlinked', location: factory.point(11.2, 47.2) })
      linking = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'OB count linking article', content_location: [poi_a.id, poi_b.id] })

      post object_browser_show_path, xhr: true, as: :json, params: {
        content_id: linking.id,
        count_only: true,
        definition: {
          type: 'linked',
          template_name: 'POI',
          ui: { edit: { options: { limited_by_linked: 'content_location' } } }
        },
        key: 'thing[datahash][content_location]',
        locale: 'de'
      }, headers: {
        referer: edit_thing_path(linking)
      }

      assert_response :success
      assert_equal 2, response.parsed_body['count']
    end

    test 'limited_by_linked ignores non-linked-property relation names and does not invoke them' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'OB unsafe POI', location: factory.point(11.0, 47.0) })
      linking = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'OB unsafe linking article' })

      # `destroy` is a public zero-arg method on the content but not a linked
      # property, so it must be filtered out and never called.
      post object_browser_show_path, xhr: true, as: :json, params: {
        content_id: linking.id,
        count_only: true,
        definition: {
          type: 'linked',
          template_name: 'POI',
          ui: { edit: { options: { limited_by_linked: 'destroy' } } }
        },
        key: 'thing[datahash][content_location]',
        locale: 'de'
      }, headers: {
        referer: edit_thing_path(linking)
      }

      assert_response :success
      assert_equal 0, response.parsed_body['count']
      assert DataCycleCore::Thing.exists?(linking.id), 'content must not be destroyed by a forged limited_by_linked relation'
    end

    test 'object browser handles a definition with an empty ui hash' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      poi = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'OB empty ui POI', location: factory.point(11.0, 47.0) })

      # The frontend posts the property definition as JSON, so an empty `ui: {}`
      # (a property without ui config) arrives as an empty hash. It must survive
      # `NormalizeService.normalize_parameters` as a hash - if it is turned into
      # `[]`, the `dig('ui', ...)` reads in the query and the grid rendering raise
      # `TypeError: no implicit conversion of Symbol into Integer`.
      post object_browser_show_path, xhr: true, as: :json, params: {
        definition: {
          type: 'linked',
          template_name: 'POI',
          ui: {}
        },
        key: 'thing[datahash][content_location]',
        locale: 'de',
        page: 1,
        per: 25
      }, headers: {
        referer: edit_thing_path(poi)
      }

      assert_response :success
      assert_includes @response.body, poi.title
    end
  end
end
