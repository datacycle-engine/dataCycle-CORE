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

    test 'sign up stays routable' do
      get new_user_registration_path

      assert_response :success
    end

    # config/routes.rb skips all registerable routes except sign up: editing or deleting
    # the own account goes through DataCycleCore::UsersController (/users/:id/edit), which
    # applies the ability checks devise's registrations#update/#destroy bypass -- guest is
    # granted [show, update] on its own user, never destroy.
    test 'devise does not expose edit, update or destroy for the own account' do
      sign_in(DataCycleCore::User.find_by(email: 'guest@datacycle.at'))

      [[:get, '/users/edit'], [:get, '/users/cancel'], [:patch, '/users'], [:put, '/users'], [:delete, '/users']].each do |method, path|
        send(method, path)

        assert_response :not_found, "#{method.upcase} #{path} is still routable"
      end
    end

    # the counterpart of the test above: what DataCycleCore::UsersController allows on the
    # own account, so widening user_actions to :destroy does not silently pass unnoticed.
    test 'the own account is editable but not deletable via UsersController' do
      guest = DataCycleCore::User.find_by(email: 'guest@datacycle.at')
      sign_in(guest)

      get edit_user_path(guest)

      assert_response :success

      delete user_path(guest)

      assert_response :redirect
      assert DataCycleCore::User.exists?(guest.id), 'guest was able to delete its own account'
    end
  end
end
