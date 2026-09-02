# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # DataCycleCore::PasswordsController < Devise::PasswordsController.
  # These endpoints carry Devise's `require_no_authentication`, so the requests
  # must run logged OUT (an authenticated session would be redirected away).
  class PasswordsControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    test 'edit renders the reset form (blank redirect_url)' do
      get edit_user_password_path, params: { reset_password_token: 'sometoken' }

      assert_response :success
    end

    test 'edit renders and evaluates a supplied redirect_url' do
      get edit_user_password_path, params: { reset_password_token: 'sometoken', redirect_url: '/backend' }

      assert_response :success
    end

    test 'create sends reset instructions for a recoverable user' do
      user = User.find_by(email: 'tester@datacycle.at')

      assert_predicate user, :recoverable?

      post user_password_path, params: { user: { email: user.email } }

      assert_response :redirect
    end

    test 'create refuses a non-recoverable (rank 0) user' do
      user = User.find_by(email: 'guest@datacycle.at')

      assert_not user.recoverable?

      post user_password_path, params: { user: { email: user.email } }

      assert_redirected_to new_user_password_path
      assert_predicate flash[:alert], :present?
    end

    test 'update resets the password given a valid token' do
      user = User.find_by(email: 'tester@datacycle.at')
      raw_token, enc_token = Devise.token_generator.generate(DataCycleCore::User, :reset_password_token)
      user.update_columns(reset_password_token: enc_token, reset_password_sent_at: Time.current)

      patch user_password_path, params: {
        user: {
          reset_password_token: raw_token,
          password: 'newSecretPass123',
          password_confirmation: 'newSecretPass123'
        }
      }

      assert_response :redirect
      assert user.reload.valid_password?('newSecretPass123')
    end
  end
end
