# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Covers RegistrationsController#create. UserRegistration is enabled in the dummy
  # app with both terms_condition_url and privacy_policy_url set, so valid_additional_attributes?
  # gates resource.save: registering with the accepted-at timestamps persists the user,
  # registering without them takes the not-persisted branch.
  class RegistrationsControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    # registration requires no authentication -> do not sign_in

    test 'create persists a new user when terms and privacy are accepted' do
      email = "cov_reg_#{Time.now.getutc.to_i}@datacycle.at"

      post user_registration_path, params: {
        user: {
          email:,
          password: 'Sup3rSecret!1',
          password_confirmation: 'Sup3rSecret!1',
          given_name: 'Cov',
          family_name: 'Reg',
          additional_attributes: { terms_conditions_at: Time.current.iso8601, privacy_policy_at: Time.current.iso8601 }
        }
      }

      assert_response :redirect
      assert DataCycleCore::User.exists?(email:)
    end

    test 'create does not persist the user without accepted terms' do
      email = "cov_reg_fail_#{Time.now.getutc.to_i}@datacycle.at"

      post user_registration_path, params: {
        user: {
          email:,
          password: 'Sup3rSecret!1',
          password_confirmation: 'Sup3rSecret!1',
          given_name: 'Cov',
          family_name: 'Reg'
        }
      }

      assert_not DataCycleCore::User.exists?(email:)
    end
  end
end
