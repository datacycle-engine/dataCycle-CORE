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
      assert @response.body.include?(@person.title)
    end

    test 'copy persons in split view' do
      post object_browser_find_path, xhr: true, as: :json, params: {
        class: @person.class.name,
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
      assert @response.body.include?(@person.title)
    end

    test 'copy persons in split view with external id' do
      external_key = 'xxx-xxx-xxx'
      @person.update(external_key: external_key)

      post object_browser_find_path, xhr: true, as: :json, params: {
        class: @person.class.name,
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
      assert @response.body.include?(@person.title)
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
      assert @response.body.include?(@person.title)
    end
  end
end
