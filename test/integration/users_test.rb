# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UsersTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @current_user = User.find_by(email: 'tester@datacycle.at')
      sign_in(@current_user)
    end

    test 'user does not exist' do
      logout

      post user_session_path, params: {
        user: {
          email: 'nonexistant@mail.com',
          password: 'nonexistant'
        }
      }, headers: {
        referer: user_session_path
      }

      assert_response :success
      assert_equal I18n.t('devise.failure.invalid', locale: DataCycleCore.ui_locales.first), flash[:alert]
    end

    test 'the detail page shows the access token masked and copyable' do
      admin = User.find_by(email: 'admin@datacycle.at')
      admin.update!(access_token: SecureRandom.hex)
      sign_in(admin)

      get user_path(admin)

      assert_response :success
      assert_select '.detail-type.access_token .password-field' do
        assert_select 'input[type=?][value=?][readonly]', 'password', admin.access_token
        assert_select 'span.copy-to-clipboard[data-value=?]', admin.access_token
      end
    end

    test 'the detail page renders no token row without a token' do
      admin = User.find_by(email: 'admin@datacycle.at')
      admin.update!(access_token: nil)
      sign_in(admin)

      get user_path(admin)

      assert_response :success
      assert_select '.detail-type.access_token', false
    end

    test 'the detail page shows the settings alongside role and user groups' do
      admin = User.find_by(email: 'admin@datacycle.at')
      admin.update!(notification_frequency: 'week', default_locale: 'de')
      sign_in(admin)

      get user_path(admin)

      assert_response :success
      assert_select '.detail-type.notification_frequency .detail-content',
                    I18n.t('notification.frequency.week', locale: DataCycleCore.ui_locales.first)
      assert_select '.detail-type.default_locale .detail-content',
                    I18n.t('locales.de', locale: DataCycleCore.ui_locales.first)
    end

    # only admin holds generate_access_token, so gating the row on it alone would have hidden every
    # other role's own token, which the sidebar used to show (#51344)
    test 'a user without generate_access_token still sees their own token' do
      guest = User.find_by(email: 'guest@datacycle.at')
      guest.update!(access_token: SecureRandom.hex)
      sign_in(guest)

      get user_path(guest)

      assert_response :success
      assert_not guest.can?(:generate_access_token, guest)
      assert_select '.detail-type.access_token input[value=?]', guest.access_token
    end

    test 'show and filter users index page' do
      @test_group_ids = DataCycleCore::UserGroup.where(name: 'TestUserGroup').pluck(:id)
      @guest = DataCycleCore::User.find_by(email: 'guest@datacycle.at')
      @guest.update(user_group_ids: @test_group_ids)

      get users_path, params: {
        q: 'guest datacycle',
        roles: DataCycleCore::Role.where(name: 'guest').pluck(:id),
        user_groups: @test_group_ids
      }

      assert_response :success
      assert_select 'li.grid-item .inner .description', { count: 1, text: 'guest@datacycle.at' }
    end

    test 'create new user' do
      user = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
        email: "tester_#{Time.now.getutc.to_i}@datacycle.at",
        role_id: DataCycleCore::Role.find_by(rank: 5)&.id,
        confirmed_at: 1.day.ago
      })

      post create_user_users_path, params: {
        user:
      }, headers: {
        referer: users_path
      }

      created_user = DataCycleCore::User.find_by(email: user[:email])

      assert_redirected_to user_path(created_user)
      assert_equal I18n.t('controllers.success.created', data: 'Benutzer', locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!

      assert_select '.detail-header-wrapper .detail-header .user-email', user[:email]
      assert_equal @current_user.id, created_user.creator.id
      assert_equal [created_user.id], @current_user.created_users.pluck(:id)
    end

    test 'update existing user' do
      user = User.find_by(email: 'guest@datacycle.at')
      patch user_path(user), params: {
        user: {
          given_name: 'Guest1',
          access_token: '1',
          default_locale: 'en',
          notification_frequency: 'week'
        }
      }, headers: {
        referer: edit_user_path(user)
      }

      assert_redirected_to users_path
      assert_equal I18n.t('controllers.success.updated', data: 'Benutzer', locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!

      assert_select 'li.grid-item > .inner > .title', "Guest1 #{user.family_name}"
      assert_select 'li.grid-item > .inner > .token input[type=?][value=?]', 'password', user.reload.access_token
      user.reload

      assert_equal 'week', user.notification_frequency
      assert_equal 'en', user.default_locale
    end

    test 'lock and unlock existing user' do
      user = User.find_by(email: 'guest@datacycle.at')

      delete lock_user_path(user), params: {}, headers: {
        referer: users_path
      }

      assert_redirected_to users_path
      assert_equal I18n.t('controllers.success.locked', data: 'Benutzer', locale: DataCycleCore.ui_locales.first), flash[:notice]

      user.reload

      assert_equal @current_user, user.locked_by
      assert_predicate user, :locked_by_user?
      assert_predicate user, :access_locked?

      get users_path

      assert_select 'li.grid-item .inner.locked > .user-lock-status + .tags', 1

      get user_path(user)

      assert_select '.detail-header .user-lock-status', text: /#{Regexp.escape(@current_user.full_name)}/
      assert_select 'a.unlock-link', 1
      assert_select 'a.lock-link', 0

      post unlock_user_path(user), params: {}, headers: {
        referer: users_path
      }

      assert_redirected_to users_path
      assert_equal I18n.t('controllers.success.unlocked', data: 'Benutzer', locale: DataCycleCore.ui_locales.first), flash[:notice]

      user.reload

      assert_nil user.locked_at
      assert_nil user.locked_by_id
    end

    test 'search returns full email for accessible users' do
      user = User.find_by(email: 'guest@datacycle.at')
      get search_users_path, xhr: true, params: {
        q: 'guest@datacycle.at'
      }

      assert_response :success
      users = JSON.parse(@response.body)
      entry = users.find { |u| u['id'] == user.id }

      assert_not_nil entry
      assert_equal user.to_select_option.name, entry['name']
      assert_includes entry['name'], 'guest@datacycle.at'
    end

    test 'search masks email for users the requester cannot access' do
      # @current_user (tester@datacycle.at) is an admin; admin@datacycle.at is a
      # super_admin and therefore not accessible to admins (DC-04 regression).
      user = User.find_by(email: 'admin@datacycle.at')
      get search_users_path, xhr: true, params: {
        q: 'admin@datacycle.at'
      }

      assert_response :success
      users = JSON.parse(@response.body)
      entry = users.find { |u| u['id'] == user.id }

      assert_not_nil entry
      assert_equal user.to_select_option(DataCycleCore.ui_locales.first, true, mask_email: true).name, entry['name']
      assert_not_includes entry['name'], 'admin@datacycle.at'
    end

    test 'become specific user' do
      sign_in(User.find_by(email: 'admin@datacycle.at'))

      post user_become_path(User.find_by(email: 'guest@datacycle.at')), params: {}, headers: {
        referer: users_path
      }

      assert_redirected_to unauthorized_exception_path
      follow_redirect!

      guest = User.find_by(email: 'guest@datacycle.at')

      assert_select 'button.show-sidebar[data-dc-tooltip=?]', guest.email do
        assert_select '> span.user-initials', guest.initials
        assert_select '> span:not(.user-initials)', guest.full_name_or_email
      end
    end

    test 'index with filters, sorting and count_only via json' do
      get users_path(format: :json), params: {
        # an unresolved filter name exercises the filter-building loop then skips via `next`
        f: { '0' => { 'c' => 'd', 'n' => 'zzz_no_such_scope', 'm' => 'i', 'v' => 'test' } },
        s: { '0' => { 'm' => 'email', 'o' => 'asc' } },
        count_only: '1',
        target: 'results',
        count_mode: 'all',
        content_class: 'User',
        mode: 'list'
      }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'validate reports errors for an invalid new user' do
      post validate_users_path, params: { user: { email: 'not-an-email', given_name: 'X' } }

      assert_response :success
      body = response.parsed_body

      assert_includes body.keys, 'valid'
      assert_includes body.keys, 'errors'
    end

    test 'validate runs against an existing user' do
      user = DataCycleCore::User.find_by(email: 'guest@datacycle.at')

      post validate_user_path(user), params: { user: { email: user.email } }

      assert_response :success
      assert response.parsed_body.key?('valid')
    end

    def build_throwaway_user(**overrides)
      attrs = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').merge(
        'email' => "throwaway_#{Time.now.getutc.to_f}@datacycle.at",
        'confirmed_at' => 1.day.ago
      ).merge(overrides.transform_keys(&:to_s))

      DataCycleCore::User.create!(attrs)
    end

    test 'destroy removes a user' do
      victim = build_throwaway_user

      delete user_path(victim), headers: { referer: users_path }

      assert_response :redirect
      assert_not DataCycleCore::User.exists?(victim.id)
    end

    test 'confirm confirms an unconfirmed user' do
      sign_in(User.find_by(email: 'admin@datacycle.at'))
      user = build_throwaway_user(confirmed_at: nil)

      assert_not user.confirmed?

      post confirm_user_path(user), headers: { referer: users_path }

      assert_response :redirect
      assert_predicate user.reload, :confirmed?
    end

    test 'consent renders the consent page for the current user' do
      get consent_users_path, params: { type: 'privacy_policy' }

      assert_response :success
    end

    test 'update_consent stores additional attributes and redirects' do
      post update_consent_users_path, params: {
        id: @current_user.id,
        user: { additional_attributes: { 'privacy_policy_at' => Time.current.to_s } }
      }

      assert_response :redirect
      assert_equal Time.current.to_s.first(4), @current_user.reload.additional_attributes['privacy_policy_at'].first(4)
    end

    test 'download_user_info_activity streams a csv (with a resolving filter)' do
      post download_user_info_activity_users_path, params: {
        # `fulltext_search` resolves on the User relation, so the filter loop actually
        # applies a scope (exercises the query.send branch) instead of skipping via `next`.
        f: { '0' => { 'c' => 'd', 'n' => 'fulltext_search', 'm' => 'i', 'v' => 'datacycle' } }
      }

      assert_response :success
      assert_equal 'text/csv', response.media_type
    end

    test 'update re-renders edit on validation failure and clears an access token' do
      user = User.find_by(email: 'guest@datacycle.at')

      patch user_path(user), params: {
        user: { email: 'not-a-valid-email', access_token: '0' }
      }, headers: { referer: edit_user_path(user) }

      assert_response :success
    end

    test 'an unhandled response format is rejected as not_acceptable' do
      get users_path(format: :xml)

      assert_response :not_acceptable
    end
  end
end
