# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserApiTest < DataCycleCore::TestCases::ActiveSupportTestCase
    teardown do
      DataCycleCore.features[:user_api].delete(:allowed_issuers)
      DataCycleCore::Feature::UserApi.reload
    end

    def update_user_api_config(config)
      rsa_private = OpenSSL::PKey::RSA.generate 2048
      rsa_public = rsa_private.public_key.to_s

      DataCycleCore.features[:user_api][:allowed_issuers] = config.transform_values do |v|
        v[:public_key] = rsa_public
        v
      end
      DataCycleCore::Feature::UserApi.reload
    end

    test 'configuration without issuer' do
      user_api = DataCycleCore::Feature::UserApi.new

      assert_nil user_api.current_issuer
      assert_equal Rails.configuration.action_mailer.default_options&.dig(:from), user_api.user_mailer_from
    end

    test 'configuration with issuer and specific config' do
      update_user_api_config({ test1: { user_mailer: { from: 'test@test.at' } } })
      user_api = DataCycleCore::Feature::UserApi.new('test1')

      assert_equal 'test1', user_api.current_issuer
      assert_equal 'test@test.at', user_api.user_mailer_from
    end

    test 'possible values for secret_for_issuer' do
      update_user_api_config({ test1: {} })

      assert_equal ENV['SECRET_KEY_BASE'].to_s, DataCycleCore::Feature::UserApi.secret_key
      assert_instance_of OpenSSL::PKey::RSA, DataCycleCore::Feature::UserApi.secret_for_issuer('test1')
      assert_equal DataCycleCore.features.dig(:user_api, :allowed_issuers, :test1, :public_key), DataCycleCore::Feature::UserApi.secret_for_issuer('test1').to_s
    end
  end
end
