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
      @current_user = User.find_by(email: 'tester@datacycle.at')
      sign_in(@current_user)
    end

    test 'create Watchlist' do
      name = "test_watch_list_#{Time.now.getutc.to_i}"

      post watch_lists_path, xhr: true, params: {
        watch_list: {
          name: name
        }
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal DataCycleCore::WatchList.where(name: name).size, 1

      get api_v2_collections_path
      assert_response :success
      assert_equal response.content_type, 'application/json'
      json_data = JSON.parse response.body
      assert_equal 1, json_data.dig('collections').select { |w| w['name'] == name }.size
    end

    test 'update Watchlist' do
      user_group = DataCycleCore::UserGroup.find_by(name: 'TestUserGroup')
      name = "test_watch_list_#{Time.now.getutc.to_i}"

      patch watch_list_path(id: @watch_list), params: {
        watch_list: {
          name: name,
          user_group_ids: [user_group.id]
        }
      }, headers: {
        referer: edit_watch_list_path(@watch_list)
      }

      assert_redirected_to watch_list_path(@watch_list)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: DataCycleCore::WatchList.model_name.human(count: 1, locale: DataCycleCore.ui_language), locale: DataCycleCore.ui_language), flash[:success]
      follow_redirect!
      assert_select '.detail-header > .title', name
    end

    test 'delete Watchlist' do
      delete watch_list_path(@watch_list), params: {}, headers: {
        referer: watch_list_path(@watch_list)
      }

      assert_redirected_to root_path
      assert_equal I18n.t(:destroyed, scope: [:controllers, :success], data: DataCycleCore::WatchList.model_name.human(count: 1, locale: DataCycleCore.ui_language), locale: DataCycleCore.ui_language), flash[:success]

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

    test 'bulk edit all watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      shared_ordered_properties = @watch_list.things.shared_ordered_properties(@current_user).keys

      get bulk_edit_watch_list_path(@watch_list), params: {}, headers: {
        referer: watch_list_path(@watch_list)
      }

      assert_response :success

      shared_ordered_properties.except('release_status_id').each do |property|
        assert_select ".form-element.#{property}"
      end
    end

    test 'bulk update all watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      bulk_name = 'Test Artikel Bulk Update 1'

      patch bulk_update_watch_list_path(@watch_list), params: {
        locale: 'de',
        thing: {
          datahash: {
            name: bulk_name
          }
        },
        bulk_update: {
          name: '1'
        }
      }, headers: {
        referer: bulk_edit_watch_list_path(@watch_list)
      }

      assert_response :success
      assert_equal I18n.t(:bulk_updated, scope: [:controllers, :success], locale: DataCycleCore.ui_language), flash[:success]
      assert_equal bulk_name, @content.name

      patch bulk_update_watch_list_path(@watch_list), params: {
        locale: 'en',
        thing: {
          datahash: {
            name: 'New Test Artikel not Bulk Updated'
          }
        },
        bulk_update: {
          name: '1'
        }
      }, headers: {
        referer: bulk_edit_watch_list_path(@watch_list)
      }

      assert_response :success
      assert_equal I18n.t(:bulk_updated, scope: [:controllers, :success], locale: DataCycleCore.ui_language) + I18n.t(:bulk_updated_skipped_html, scope: [:controllers, :info], data: I18n.with_locale(@content.first_available_locale) { @content.name }, locale: DataCycleCore.ui_language), flash[:success]
      assert_equal bulk_name, @content.name
    end

    test 'validate (bulk update) watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      bulk_name = 'Test Artikel Bulk Update 1'

      post validate_watch_list_path(@watch_list), xhr: true, params: {
        thing: {
          datahash: {
            name: bulk_name
          }
        },
        bulk_update: {
          name: '1'
        }
      }, headers: {
        referer: bulk_edit_watch_list_path(@watch_list)
      }

      assert_response :success
      assert_equal 'application/json', response.content_type
      json_data = JSON.parse response.body
      assert json_data['error'].blank?
    end
  end
end
