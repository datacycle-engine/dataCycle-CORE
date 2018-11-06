# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class WatchListsTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'create Watchlist' do
      name = "test_watch_list_#{Time.now.getutc.to_i}"

      post watch_lists_path, xhr: true, params: {
        watch_list: {
          headline: name
        }
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal DataCycleCore::WatchList.where(headline: name).size, 1

      get api_v2_collections_path
      assert_response :success
      assert_equal response.content_type, 'application/json'
      json_data = JSON.parse response.body
      assert_equal 1, json_data.dig('collections').select { |w| w['name'] == name }.size
    end

    test 'update Watchlist' do
      user_group = DataCycleCore::UserGroup.find_by(name: 'TestUserGroup')
      name = "test_watch_list_#{Time.now.getutc.to_i}"

      patch watch_list_path(@watch_list), params: {
        watch_list: {
          headline: name,
          user_group_ids: [user_group.id]
        }
      }, headers: {
        referer: edit_watch_list_path(@watch_list)
      }

      assert_redirected_to watch_list_path(@watch_list)
      assert_equal 'Inhaltssammlung wurde aktualisiert.', flash[:success]
      follow_redirect!
      assert_select '.detail-header > .title', name
    end

    test 'delete Watchlist' do
      delete watch_list_path(@watch_list), params: {}, headers: {
        referer: watch_list_path(@watch_list)
      }

      assert_redirected_to watch_lists_path
      assert_equal 'Inhaltssammlung wurde gelöscht.', flash[:success]

      get api_v2_collections_path
      assert_response :success
      assert_equal response.content_type, 'application/json'
      json_data = JSON.parse response.body
      assert_equal json_data.dig('collections').size, 0
    end

    test 'add content to watch_list' do
      get add_item_watch_list_path(@watch_list), xhr: true, params: {
        hashable_id: @content.id,
        hashable_type: @content.class.name
      }, headers: {
        referer: root_path
      }

      assert_response :success

      get watch_list_path(@watch_list)
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestArtikel'

      get api_v2_collection_path(@watch_list)
      assert_response :success
      assert_equal response.content_type, 'application/json'
      json_data = JSON.parse response.body
      assert_equal json_data.dig('collection', 'items').size, 1
    end

    test 'remove content from watch_list' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)

      delete remove_item_watch_list_path(@watch_list), xhr: true, params: {
        hashable_id: @content.id,
        hashable_type: @content.class.name
      }, headers: {
        referer: root_path
      }

      assert_response :success

      get watch_list_path(@watch_list)
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', { count: 0, text: 'TestArtikel' }

      get api_v2_collection_path(@watch_list)
      assert_response :success
      assert_equal response.content_type, 'application/json'
      json_data = JSON.parse response.body
      assert_equal json_data.dig('collection', 'items').size, 0
    end
  end
end
