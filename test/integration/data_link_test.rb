# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UsersTest < ActionDispatch::IntegrationTest
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
        referer: thing_path(@content)
      }
      follow_redirect!

      data_link = @content.data_links.includes(:receiver).find_by(users: { email: user['email'] })

      assert data_link

      get data_link_path(data_link)
      assert_redirected_to edit_thing_path(@content)
    end

    test 'lock external link' do
      delete data_link_path(@data_link), params: {}, headers: {
        referer: thing_path(@content)
      }
      assert_redirected_to thing_path(@content)
      follow_redirect!

      get data_link_path(@data_link)
      assert_redirected_to root_path
    end

    test 'can only edit owned data_links' do
      sign_in(User.find_by(email: 'admin@datacycle.at'))

      patch data_link_path(@data_link), params: {
        data_link: {
          comment: 'hahaha, i hacked the link'
        }
      }, headers: {
        referer: thing_path(@content)
      }

      assert_redirected_to thing_path(@content)
      assert_equal 'Keine Zugriffsberechtigung!', flash[:alert]
    end
  end
end
