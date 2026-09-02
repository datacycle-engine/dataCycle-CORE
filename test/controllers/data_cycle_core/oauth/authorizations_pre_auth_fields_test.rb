# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Oauth
    # The consent screen is the only place that carries the authorization request across the
    # user's decision: Doorkeeper rebuilds the PreAuthorization from the POSTed params alone
    # (AuthorizationsController#pre_auth_params), so a field the form forgets is silently lost.
    #
    # Doorkeeper's stock view hardcodes its own field list and already misses :nonce, which
    # doorkeeper-openid_connect appends to pre_auth_param_fields. This pins our replacement view
    # against the list the controller actually reads, so a gem upgrade that adds a field fails
    # here instead of quietly breaking a login.
    class AuthorizationsPreAuthFieldsTest < DataCycleCore::TestCases::ActiveSupportTestCase
      PRE_AUTH_ATTRIBUTES = {
        client_id: 'UID-TEST',
        response_type: 'code',
        redirect_uri: 'https://example.org/callback',
        scope: 'public openid',
        state: 'state-value',
        nonce: 'nonce-value',
        code_challenge: 'challenge-value',
        code_challenge_method: 'S256',
        response_mode: 'query'
      }.freeze

      setup do
        @application = Doorkeeper::Application.new(
          name: 'Test Application',
          uid: PRE_AUTH_ATTRIBUTES[:client_id],
          secret: 'secret',
          redirect_uri: PRE_AUTH_ATTRIBUTES[:redirect_uri]
        )
      end

      test 'consent form echoes every field pre_auth_params reads back' do
        names = submitted_field_names(render_consent_page)

        assert_empty expected_fields - names,
                     'consent form is missing hidden fields required to rebuild the pre-authorization'
      end

      test 'consent form carries the OIDC nonce through the user decision' do
        html = render_consent_page

        assert_includes submitted_field_names(html), 'nonce'
        assert_includes html, PRE_AUTH_ATTRIBUTES[:nonce]
      end

      private

      # The list Doorkeeper permits on the POST/DELETE, including anything gems prepend onto it.
      def expected_fields
        Doorkeeper::AuthorizationsController.new.send(:pre_auth_param_fields).map(&:to_s)
      end

      def submitted_field_names(html)
        html.scan(/<input[^>]*type="hidden"[^>]*>/).filter_map { |input| input[/name="([^"]+)"/, 1] }.uniq
      end

      def render_consent_page
        DataCycleCore::Oauth::AuthorizationsController.render(
          template: 'data_cycle_core/oauth/authorizations/new',
          layout: false,
          assigns: { pre_auth: }
        )
      end

      def pre_auth
        pre_auth = Doorkeeper::OAuth::PreAuthorization.new(
          Doorkeeper.config,
          PRE_AUTH_ATTRIBUTES.with_indifferent_access
        )
        # PreAuthorization only looks the client up while validating, which would need a DB record.
        pre_auth.instance_variable_set(:@client, Doorkeeper::OAuth::Client.new(@application))
        pre_auth
      end
    end
  end
end
