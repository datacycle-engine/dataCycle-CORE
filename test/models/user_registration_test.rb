# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserRegistrationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @user = DataCycleCore::User.create!(
        given_name: 'Test',
        family_name: 'TEST',
        email: "#{SecureRandom.base64(12)}@pixelpoint.at",
        password: 'password'
      )
    end

    setup do
      @user_registration_before_state = DataCycleCore.features[:user_registration].deep_dup
      DataCycleCore.features[:user_registration][:enabled] = true
      DataCycleCore::Feature::UserRegistration.reload
    end

    teardown do
      DataCycleCore.features = DataCycleCore.features.except(:user_registration).merge({ user_registration: @user_registration_before_state })
      DataCycleCore::Feature::UserRegistration.reload
    end

    test 'terms_conditions_changed? false' do
      assert_equal(false, DataCycleCore::Feature::UserRegistration.terms_conditions_changed?(@user.additional_attributes&.dig('terms_conditions_at')))
    end

    test 'privacy_policy_changed? false' do
      assert_equal(false, DataCycleCore::Feature::UserRegistration.privacy_policy_changed?(@user.additional_attributes&.dig('privacy_policy_at')))
    end

    test 'users_outside_grace_period false' do
      assert_equal(0, DataCycleCore::Feature::UserRegistration.users_outside_grace_period.size)
    end

    test 'users_outside_grace_period false 3.weeks.ago' do
      assert_equal(0, DataCycleCore::Feature::UserRegistration.users_outside_grace_period.size)
    end

    test 'terms_conditions_changed? true' do
      DataCycleCore.features[:user_registration][:consent_grace_period] = 2.weeks
      DataCycleCore.features[:user_registration][:terms_condition_updated_at] = Time.zone.now.iso8601
      DataCycleCore::Feature::UserRegistration.reload

      @user.update(additional_attributes: {
        'terms_conditions_at' => 1.week.ago.iso8601
      })

      assert_equal(true, DataCycleCore::Feature::UserRegistration.terms_conditions_changed?(@user.additional_attributes&.dig('terms_conditions_at')))
    end

    test 'privacy_policy_changed? true' do
      DataCycleCore.features[:user_registration][:consent_grace_period] = 2.weeks
      DataCycleCore.features[:user_registration][:privacy_policy_updated_at] = Time.zone.now.iso8601
      DataCycleCore::Feature::UserRegistration.reload

      @user.update(additional_attributes: {
        'privacy_policy_at' => 1.week.ago.iso8601
      })

      assert_equal(true, DataCycleCore::Feature::UserRegistration.privacy_policy_changed?(@user.additional_attributes&.dig('privacy_policy_at')))
    end

    test 'users_outside_grace_period true' do
      DataCycleCore.features[:user_registration][:consent_grace_period] = 2.weeks
      DataCycleCore.features[:user_registration][:terms_condition_updated_at] = 3.weeks.ago.iso8601
      DataCycleCore::Feature::UserRegistration.reload

      @user.update(additional_attributes: {
        'terms_conditions_at' => Time.zone.now.iso8601
      })

      DataCycleCore::User.update_all(created_at: 3.weeks.ago)

      assert_equal(
        DataCycleCore::User.where(locked_at: nil).size - 1,
        DataCycleCore::Feature::UserRegistration.users_outside_grace_period.size
      )
    end
  end
end
