# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SideBarTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @routes = Engine.routes
    end

    setup do
      @super_admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @system_admin = DataCycleCore::User.find_by(email: 'system_admin@datacycle.at')
    end

    test 'the profile entry links the signed in user' do
      sign_in(@super_admin)

      get root_path

      assert_response :success
      assert_select 'a.show-user-link[href=?]', user_path(@super_admin) do
        assert_select 'span.title', I18n.t('data_cycle_core.side_bar.profile', locale: DataCycleCore.ui_locales.first)
      end
    end

    # the token moved to the user's detail page so it is not exposed in screen shares (#51344);
    # DataCycleCore::UsersTest covers it there
    test 'the access token is not exposed in the sidebar' do
      @super_admin.update!(access_token: SecureRandom.hex)
      sign_in(@super_admin)

      get root_path

      assert_response :success
      assert_select '#settings-off-canvas .access-token', false
      assert_select '#settings-off-canvas input[type=?]', 'password', false
    end

    # the guides document dataCycle internals, so super_admin lost the entry it used to get through
    # its `:home, :dash_board` grant (#51344)
    test 'the guides entry is reserved for system_admin' do
      sign_in(@system_admin)

      get root_path

      assert_response :success
      assert_select 'a.guides-link[href=?]', guides_path

      sign_in(@super_admin)

      get root_path

      assert_response :success
      assert_select 'a.guides-link', false
    end

    test 'the info entry follows DataCycleCore.info_link' do
      sign_in(@super_admin)

      {
        nil => 'https://datacycle.info/',
        'https://info.example.com/' => 'https://info.example.com/',
        :info => info_path
      }.each do |configured, expected|
        DataCycleCore.info_link = configured

        get root_path

        assert_response :success
        assert_select 'a.info-link[href=?]', expected
      end
    ensure
      DataCycleCore.info_link = nil
    end

    # PermissionsList#permissions loads exactly these; a project prepends its own loader for its own
    # roles (VTG grants :show on the own user in app/extensions/permissions/roles/event_editor.rb).
    # TestPreparations seeds further roles that match no loader and hold no user permission at all.
    CORE_ROLES = ['guest', 'external_user', 'standard', 'admin', 'super_admin', 'system_admin'].freeze

    # every role has to reach its own profile: the sidebar entry is gated on can?(:show, current_user)
    # and the page authorizes :show on the same user, so a role holding one without the other would
    # get a menu entry leading to a 401, or no entry on a page it can open (#51344)
    test 'every core role reaches its own profile from the sidebar' do
      CORE_ROLES.each do |role_name|
        role = DataCycleCore::Role.find_by(name: role_name)

        assert_not_nil role, "role #{role_name} is missing"

        user = DataCycleCore::User.find_by(role:) || DataCycleCore::User.create!(
          email: "profile_#{role_name}@datacycle.at",
          password: 'v3ry-s3cr3t-p4ssw0rd',
          role:,
          confirmed_at: 1.day.ago,
          # system_admin is rejected without an oauth provider (User#system_admin_requires_oauth)
          providers: role.rank == 100 ? { keycloak: SecureRandom.uuid } : {}
        )

        sign_in(user)

        # the profile page renders the layout, so one request covers the entry and its target.
        # root_path would not: guest holds no :backend subject and 401s there, though it does reach
        # the menu on the pages it can open, such as /docs.
        get user_path(user)

        assert_response :success, "#{role_name} cannot open its own profile page"
        assert_select 'a.show-user-link[href=?]', user_path(user), 1,
                      "#{role_name} has no profile entry in the sidebar"
      end
    end

    test 'the logout entry sits in its own segment below every section' do
      sign_in(@super_admin)

      get root_path

      assert_response :success
      assert_select '#settings-off-canvas > .settings-row:last-child.logout-row' do
        assert_select 'a.logout-link[href=?]', destroy_user_session_path
      end
    end
  end
end
