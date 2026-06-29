# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for DataCycleCore::User methods not exercised by the spec-based
  # user_test.rb: omniauth lookups, webhooks, select options and status helpers.
  class UserCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
    end

    def build_user(**attrs)
      DataCycleCore::User.create!({
        given_name: 'Cov',
        family_name: 'User',
        email: "#{SecureRandom.hex(6)}@pixelpoint.at",
        password: 'password'
      }.merge(attrs))
    end

    test 'additional_webhook_attributes includes the providers attribute' do
      assert_includes @admin.additional_webhook_attributes, 'providers'
    end

    test 'recoverable? is true for an internal ranked user' do
      assert_predicate @admin, :recoverable?
    end

    test 'send_notification delivers the subscription mailer only for present ids' do
      mail = struct_double(deliver_later: true)

      assert_nil @admin.send_notification([])

      DataCycleCore::SubscriptionMailer.stub(:notify, ->(*, **) { mail }) do
        assert @admin.send_notification(['some-content-id'])
      end
    end

    test 'from_omniauth initializes, configures and saves a new external user' do
      # :pixelpoint_aad_v2 is always registered in the test env — test/dummy supplies dummy AAD
      # credentials when none are set (CI included). The email must sit in the provider's
      # allowed_email_domains (DC-25), which devise.rb defaults to pixelpoint.at,datacycle.info.
      auth = struct_double(
        provider: 'pixelpoint_aad_v2',
        uid: "omni-#{SecureRandom.hex(4)}",
        info: struct_double(email: "omni-#{SecureRandom.hex(4)}@pixelpoint.at", first_name: 'Omni', last_name: 'User')
      )
      yielded = false

      user = DataCycleCore::User.from_omniauth(auth) { |_u| yielded = true }

      assert_predicate user, :persisted?
      assert_predicate user, :external?
      assert yielded
      assert_equal('Omni', user.given_name)
    end

    test 'from_omniauth accepts the secondary allowlisted domain datacycle.info (DC-25)' do
      auth = struct_double(
        provider: 'pixelpoint_aad_v2',
        uid: "omni-#{SecureRandom.hex(4)}",
        info: struct_double(email: "omni-#{SecureRandom.hex(4)}@datacycle.info", first_name: 'Data', last_name: 'Cycle')
      )

      assert_predicate DataCycleCore::User.from_omniauth(auth), :persisted?
    end

    test 'from_omniauth rejects an email domain outside the provider allowlist (DC-25)' do
      email = "intruder-#{SecureRandom.hex(4)}@example.com"
      auth = struct_double(
        provider: 'pixelpoint_aad_v2',
        uid: "omni-#{SecureRandom.hex(4)}",
        info: struct_double(email:, first_name: 'In', last_name: 'Truder')
      )

      assert_nil DataCycleCore::User.from_omniauth(auth)
      assert_not DataCycleCore::User.exists?(email:)
    end

    test 'as_user_api_json and to_select_options map over all users' do
      assert_kind_of Array, DataCycleCore::User.as_user_api_json
      assert_kind_of Array, DataCycleCore::User.to_select_options
    end

    test 'full_name_with_status marks locked users' do
      user = build_user(locked_at: Time.zone.now)

      assert_includes user.full_name_with_status, 'alert-color'
    end

    test 'with_deleted unscopes the deleted_at default scope' do
      assert_kind_of ActiveRecord::Relation, DataCycleCore::User.with_deleted
    end

    test 'group_names lists the user group names' do
      assert_includes @admin.group_names, 'Administrators'
    end

    test 'confirmable? and registerable? reflect the enabled devise modules' do
      assert_includes [true, false], @admin.confirmable?
      assert_includes [true, false], @admin.registerable?
    end

    test 'set_default_role falls back to Role.default without user registration' do
      DataCycleCore::Feature::UserRegistration.stub(:enabled?, false) do
        user = DataCycleCore::User.new
        user.send(:set_default_role)

        assert_equal DataCycleCore::Role.default, user.role
      end
    end

    test 'reset_ui_locale resets an invalid ui_locale on save' do
      user = build_user
      user.update(ui_locale: 'zz-not-a-locale')

      assert_equal DataCycleCore::User.column_defaults['ui_locale'], user.ui_locale
    end

    test 'system_admin role requires oauth providers' do
      system_admin = DataCycleCore::Role.find_by(name: 'system_admin')
      user = DataCycleCore::User.new(
        email: "sa-#{SecureRandom.hex(6)}@pixelpoint.at",
        password: 'password',
        role: system_admin,
        providers: {}
      )

      assert_not user.valid?
      assert user.errors.added?(:role_id, :system_admin_requires_oauth)
    end

    test 'execute_delete_webhooks dispatches the delete webhook' do
      called = false

      DataCycleCore::Webhook::Delete.stub(:execute_all, ->(_u) { called = true }) do
        @admin.send(:execute_delete_webhooks)
      end

      assert called
    end
  end
end
