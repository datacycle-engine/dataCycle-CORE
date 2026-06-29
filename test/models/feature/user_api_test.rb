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

    def admin
      DataCycleCore::User.find_by(email: 'admin@datacycle.at')
    end

    test 'hash_to_allowed_params maps has_many and nested hash keys' do
      result = DataCycleCore::Feature::UserApi.new.hash_to_allowed_params({ 'watch_lists' => nil, 'nested' => { 'inner' => 1 } })

      assert_kind_of Array, result
      assert(result.any? { |e| e.is_a?(::Hash) && e.keys.first.to_s.end_with?('Ids') })
      assert(result.any? { |e| e.is_a?(::Hash) && e[:nested].present? })
    end

    test 'allowed_role resolves a role by rank' do
      assert_kind_of DataCycleCore::Role, DataCycleCore::Feature::UserApi.new.allowed_role(0)
    end

    test 'default_user_groups queries the configured groups' do
      feature = DataCycleCore::Feature::UserApi.new

      feature.stub(:configuration, { default_user_groups: ['Nonexistent Group'] }) do
        assert_equal 0, feature.default_user_groups.count
      end
    end

    test 'users_to_notify collects emails from the configured group and address' do
      feature = DataCycleCore::Feature::UserApi.new

      feature.stub(:configuration, { new_user_notification: { user_group: 'Nonexistent Group', email: 'notify@test.at' } }) do
        assert_equal ['notify@test.at'], feature.users_to_notify
      end
    end

    test 'notify_users enqueues a user api mail' do
      feature = DataCycleCore::Feature::UserApi.new('iss', admin)
      sent = false
      feature.stub(:configuration, { new_user_notification: { email: 'notify@test.at' } }) do
        DataCycleCore::UserApiMailer.stub(:notify, ->(*) { struct_double(deliver_later: (sent = true)) }) do
          feature.notify_users
        end
      end

      assert sent
    end

    test 'notify_confirmed_user enqueues a confirmation mail' do
      feature = DataCycleCore::Feature::UserApi.new('iss', admin)
      sent = false
      DataCycleCore::UserApiMailer.stub(:notify_confirmed, ->(*) { struct_double(deliver_later: (sent = true)) }) do
        feature.notify_confirmed_user
      end

      assert sent
    end

    test 'user_confirmed_for_api? is false when the user is not in the confirmation group' do
      feature = DataCycleCore::Feature::UserApi.new('iss', admin)

      feature.stub(:configuration, { new_user_confirmation: { user_group: 'Nonexistent Group' } }) do
        assert_not feature.user_confirmed_for_api?
      end
    end

    test 'additional_tile_values reads jsonb and plain columns' do
      feature = DataCycleCore::Feature::UserApi.new
      DataCycleCore::Feature::UserApi.stub(:enabled?, true) do
        feature.stub(:configuration, { additional_tile_attributes: { 'additional_attributes' => { 'foo' => 1 }, 'email' => {} } }) do
          result = feature.additional_tile_values(admin)

          assert_kind_of Hash, result
          assert_equal admin.email, result['email']
        end
      end
    end

    test 'json_params builds include options for has_many params' do
      feature = DataCycleCore::Feature::UserApi.new
      feature.stub(:configuration, { user_params: { 'watch_lists' => ['name'], 'subscriptions' => { 'a' => 1 }, 'stored_filters' => nil } }) do
        includes = feature.json_params[:include]

        assert_equal({ only: ['name'] }, includes[:watch_lists])
        assert_equal({ only: ['a'] }, includes[:subscriptions])
        assert_equal({}, includes[:stored_filters])
      end
    end

    test 'new_user_confirmations_issuer finds the issuer for a confirmation group' do
      update_user_api_config({ iss1: { new_user_confirmation: { user_group: 'GroupX' } } })

      assert_equal 'iss1', DataCycleCore::Feature::UserApi.new_user_confirmations_issuer('GroupX').to_s
    end
  end
end
