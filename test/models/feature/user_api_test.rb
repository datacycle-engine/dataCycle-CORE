# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserApiTest < DataCycleCore::TestCases::ActiveSupportTestCase
    setup do
      @original_allowed_redirect_hosts = DataCycleCore.features[:user_api][:allowed_redirect_hosts]
    end

    teardown do
      DataCycleCore.features[:user_api].delete(:allowed_issuers)
      DataCycleCore.features[:user_api][:allowed_redirect_hosts] = @original_allowed_redirect_hosts
      DataCycleCore::Feature::UserApi.reload
    end

    def configure_allowed_redirect_hosts(hosts)
      DataCycleCore.features[:user_api][:allowed_redirect_hosts] = hosts
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

    test 'redirect_url_allowed? matches exact hosts, wildcards and relative urls (DC-11)' do
      configure_allowed_redirect_hosts(['*.dummy.com', 'trusted.example.com'])

      # relative / first-party urls are always allowed
      assert DataCycleCore::Feature::UserApi.redirect_url_allowed?('/reset?token=abc')
      assert DataCycleCore::Feature::UserApi.redirect_url_allowed?('reset/done')

      # exact host
      assert DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://trusted.example.com/reset')

      # wildcard: apex plus subdomains at any depth
      assert DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://dummy.com/reset')
      assert DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://app.dummy.com/reset')
      assert DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://a.b.dummy.com/reset')

      # the optional FQDN root dot is normalized away
      assert DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://app.dummy.com./reset')

      # look-alikes and unlisted hosts are rejected
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://notdummy.com/reset')
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://dummy.com.evil.com/reset')
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://evil.com/reset')

      # scheme without a host (javascript:, mailto:) is rejected
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('javascript:alert(1)')

      # blank input is rejected
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?(nil)
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('')
    end

    test 'redirect_url_allowed? rejects parser-divergence open-redirect bypasses (DC-11)' do
      configure_allowed_redirect_hosts(['*.dummy.com', 'trusted.example.com'])

      # browsers turn "\" into "/" -> these become protocol-relative to evil.com,
      # but Addressable parses them as scheme-less/host-less relative paths
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('/\evil.com')
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('\\/evil.com')
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('\\\\evil.com')

      # extra leading slashes parse with a blank host but are protocol-relative in a browser
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('////evil.com')

      # backslash-in-userinfo: Addressable sees host app.dummy.com, a browser sees evil.com
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://evil.com\@app.dummy.com/')

      # embedded control chars (stripped by browsers before parsing) are rejected
      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?("https://evil.com\t.dummy.com/")
    end

    test 'redirect_url_allowed? fails closed when allowlist is empty (DC-11)' do
      configure_allowed_redirect_hosts([])

      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://dummy.com/reset')
      # relative urls remain allowed even with an empty allowlist
      assert DataCycleCore::Feature::UserApi.redirect_url_allowed?('/reset')
    end

    test 'bare * is treated as a literal host, not a catch-all (DC-11)' do
      configure_allowed_redirect_hosts(['*'])

      assert_not DataCycleCore::Feature::UserApi.redirect_url_allowed?('https://anything.example.org/x')
    end

    test 'per-issuer allowlist replaces the global one for that issuer (DC-11)' do
      configure_allowed_redirect_hosts(['*.dummy.com'])
      update_user_api_config({ issuer_a: { allowed_redirect_hosts: ['issuer-a.example.com'] } })

      with_issuer = DataCycleCore::Feature::UserApi.new('issuer_a')

      assert with_issuer.allowed_redirect_url?('https://issuer-a.example.com/reset')
      # the issuer config replaces (does not union) the global list
      assert_not with_issuer.allowed_redirect_url?('https://app.dummy.com/reset')

      without_issuer = DataCycleCore::Feature::UserApi.new

      assert without_issuer.allowed_redirect_url?('https://app.dummy.com/reset')
    end

    test 'possible values for secret_for_issuer' do
      update_user_api_config({ test1: {} })

      assert_equal ENV['SECRET_KEY_BASE'].to_s, DataCycleCore::Feature::UserApi.secret_key
      assert_instance_of OpenSSL::PKey::RSA, DataCycleCore::Feature::UserApi.secret_for_issuer('test1')
      assert_equal DataCycleCore.features.dig(:user_api, :allowed_issuers, :test1, :public_key), DataCycleCore::Feature::UserApi.secret_for_issuer('test1').to_s
    end
  end
end
