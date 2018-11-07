# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DataLinkTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      @data_link = DataCycleCore::DataLink.find_or_create_by({
        item_id: @content.id,
        item_type: @content.class.name,
        creator_id: User.find_by(email: 'tester@datacycle.at')&.id,
        receiver_id: User.find_by(email: 'guest@datacycle.at')&.id,
        permissions: 'write'
      })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'create new external link for content' do
      user = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'data_link_user')
      readonly_content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel not editable' })

      post data_links_path, params: {
        data_link: {
          receiver: user,
          valid_from: Time.zone.now,
          valid_until: Time.zone.tomorrow,
          permissions: 'write',
          item_id: @content.id,
          item_type: @content.class.name,
          comment: 'Testkommentar'
        }
      }, headers: {
        referer: polymorphic_path(@content)
      }
      follow_redirect!

      data_link = @content.data_links.includes(:receiver).find_by(users: { email: user['email'] })

      assert data_link

      logout
      get data_link_path(data_link)
      assert_redirected_to edit_polymorphic_path(@content)
      follow_redirect!

      get edit_polymorphic_path(readonly_content)
      assert_equal 'Keine Berechtigung.', flash[:alert]
      assert_redirected_to polymorphic_path(readonly_content)
    end

    test 'create new external link for watch_list' do
      user = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'data_link_user')
      watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
      watch_list_content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel in WatchList' })
      DataCycleCore::WatchListDataHash.find_or_create_by({
        watch_list_id: watch_list.id,
        hashable_id: watch_list_content.id,
        hashable_type: watch_list_content.class.name
      })

      post data_links_path, params: {
        data_link: {
          receiver: user,
          valid_from: Time.zone.now,
          valid_until: Time.zone.tomorrow,
          permissions: 'write',
          item_id: watch_list.id,
          item_type: watch_list.class.name,
          comment: 'Testkommentar'
        }
      }, headers: {
        referer: polymorphic_path(watch_list)
      }
      follow_redirect!

      data_link = watch_list.data_links.includes(:receiver).find_by(users: { email: user['email'] })
      assert data_link

      get add_item_watch_list_path(watch_list), xhr: true, params: {
        hashable_id: @content.id,
        hashable_type: @content.class.name
      }, headers: {
        referer: root_path
      }

      assert_response 403

      delete remove_item_watch_list_path(watch_list), xhr: true, params: {
        hashable_id: watch_list_content.id,
        hashable_type: watch_list_content.class.name
      }, headers: {
        referer: root_path
      }

      assert_response 403

      logout
      get data_link_path(data_link)
      assert_redirected_to polymorphic_path(watch_list)
      follow_redirect!

      get edit_polymorphic_path(watch_list_content)
      assert_response :success
    end

    test 'lock external link' do
      delete data_link_path(@data_link), params: {}, headers: {
        referer: polymorphic_path(@content)
      }
      assert_redirected_to polymorphic_path(@content)
      follow_redirect!

      logout
      assert_response :success

      get data_link_path(@data_link)
      assert_redirected_to root_path
      follow_redirect!
      assert_redirected_to new_user_session_path
    end

    test 'can only edit owned data_links' do
      sign_in(User.find_by(email: 'admin@datacycle.at'))

      patch data_link_path(@data_link), params: {
        data_link: {
          comment: 'hahaha, i hacked the link'
        }
      }, headers: {
        referer: polymorphic_path(@content)
      }

      assert_redirected_to polymorphic_path(@content)
      assert_equal 'Keine Zugriffsberechtigung!', flash[:alert]
      @data_link.reload
      assert_nil @data_link.comment
    end
  end
end
