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
      @current_user = User.find_by(email: 'tester@datacycle.at')
      sign_in(@current_user)
    end

    test 'create new external link for content' do
      user = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'data_link_user').merge({ confirmed_at: Time.zone.now - 1.day })

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
        referer: polymorphic_url(@content)
      }
      follow_redirect!

      data_link = @content.data_links.includes(:receiver).find_by(users: { email: user['email'] })

      assert data_link

      logout

      get data_link_path(data_link)
      assert_redirected_to edit_thing_path(@content)
      follow_redirect!

      get edit_polymorphic_path(readonly_content)
      assert_equal I18n.t(:all, scope: [:unauthorized, :manage], locale: DataCycleCore.ui_locales.first), flash[:alert]
      assert_redirected_to unauthorized_exception_path
    end

    test 'create new external link for content and existing user' do
      @data_link.destroy
      user = User.find_by(email: 'guest@datacycle.at')
      readonly_content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel not editable' })

      post data_links_path, params: {
        data_link: {
          receiver: {
            id: user.id,
            email: user.email
          },
          valid_from: Time.zone.now,
          valid_until: Time.zone.tomorrow,
          permissions: 'write',
          item_id: @content.id,
          item_type: @content.class.name,
          comment: 'Testkommentar'
        }
      }, headers: {
        referer: polymorphic_url(@content)
      }
      follow_redirect!

      data_link = @content.data_links.includes(:receiver).find_by(users: { email: user['email'] })

      assert data_link

      logout

      get data_link_path(data_link)
      assert_redirected_to edit_thing_path(@content)
      follow_redirect!

      get edit_polymorphic_path(readonly_content)
      assert_equal I18n.t(:all, scope: [:unauthorized, :manage], locale: DataCycleCore.ui_locales.first), flash[:alert]
      assert_redirected_to unauthorized_exception_path
    end

    test 'create new external link for watch_list' do
      user = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'data_link_user').merge({ confirmed_at: Time.zone.now - 1.day })
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
          item_type: watch_list.class.base_class.name,
          comment: 'Testkommentar'
        }
      }, headers: {
        referer: polymorphic_url(watch_list)
      }
      follow_redirect!

      data_link = watch_list.data_links.includes(:receiver).find_by(users: { email: user['email'] })
      assert data_link

      delete remove_item_watch_list_path(watch_list), xhr: true, params: {
        hashable_id: watch_list_content.id,
        hashable_type: watch_list_content.class.name
      }, headers: {
        referer: root_url
      }

      assert_response 200

      get add_item_watch_list_path(watch_list), xhr: true, params: {
        hashable_id: watch_list_content.id,
        hashable_type: watch_list_content.class.name
      }, headers: {
        referer: root_url
      }

      assert_response 200

      logout

      get data_link_path(data_link)
      assert_redirected_to polymorphic_path(watch_list)
      follow_redirect!

      get edit_polymorphic_path(watch_list_content)
      assert_response :success
    end

    test 'update external link for content' do
      patch data_link_path(@data_link), params: {
        data_link: {
          valid_from: Time.zone.now,
          valid_until: Time.zone.tomorrow,
          comment: 'Testkommentar 2'
        }
      }, headers: {
        referer: polymorphic_url(@content)
      }
      follow_redirect!

      @data_link.reload
      assert @content.data_links.includes(:receiver).find_by(users: { email: @data_link.receiver.email })
      assert_equal 'Testkommentar 2', @data_link.comment
    end

    test 'lock external link' do
      delete data_link_path(@data_link), params: {}, headers: {
        referer: thing_url(@content)
      }
      assert_redirected_to thing_path(@content)
      follow_redirect!

      logout

      get data_link_path(@data_link)
      assert_redirected_to unauthorized_exception_path
    end

    test 'unlock external link' do
      @data_link.update(valid_until: 1.minute.ago)

      patch unlock_data_link_path(@data_link), params: {}, headers: {
        referer: thing_url(@content)
      }
      assert_redirected_to thing_path(@content)
      follow_redirect!

      assert_nil @data_link.reload.valid_until

      logout

      get data_link_path(@data_link)
      assert_redirected_to edit_thing_path(@content)
    end

    test 'can only edit owned data_links' do
      user = DataCycleCore::User.where(email: 'normal_admin@datacycle.at').first_or_create({
        given_name: 'normal',
        family_name: 'admin',
        password: Devise.friendly_token,
        confirmed_at: Time.zone.now - 1.day,
        role_id: DataCycleCore::Role.find_by(name: 'admin')&.id
      })

      sign_in(user)

      patch data_link_path(@data_link), params: {
        data_link: {
          comment: 'hahaha, i hacked the link'
        }
      }, headers: {
        referer: thing_url(@content)
      }

      assert_redirected_to root_path
      assert_equal I18n.t('unauthorized.manage.all', locale: DataCycleCore.ui_locales.first), flash[:alert]
      assert_nil @data_link.reload.comment
    end

    test 'set external link to readonly after finishing' do
      sign_out(@current_user)
      get data_link_path(@data_link)
      assert_redirected_to edit_thing_path(@content)
      follow_redirect!

      patch thing_path(@content), params: {
        thing: {
          datahash: @content.get_data_hash
        },
        finalize: true
      }, headers: {
        referer: edit_thing_url(@content)
      }

      assert_redirected_to thing_path(@content, locale: I18n.locale)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_equal 'read', @data_link.reload.permissions
    end
  end
end
