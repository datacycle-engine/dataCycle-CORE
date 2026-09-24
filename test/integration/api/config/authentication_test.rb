# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module Config
      # Guards the authentication/authorization on the /api/config/* endpoints:
      #   * the `authenticate` block that wraps `namespace :api` in config/routes.rb
      #     blocks anonymous access (401) — no per-controller guard is involved
      #   * the raw config and the RDF schema are system_admin-only. Those four subjects
      #     (:api_config_schema, :api_config_features, :api_config_common and
      #     :api_config_rdf) are granted in one `read_api_configs` ability in
      #     roles/system_admin.yml, and only role :system_admin loads that file.
      #   * the OpenAPI document and its Swagger UI viewer carry no subject at all --
      #     they describe the API the caller may already use, so authentication is the
      #     whole gate and any logged-in user reaches them.
      class AuthenticationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @routes = Engine.routes

          # Only role :system_admin loads system_admin.yml — is_role? is an exact match, so
          # super_admin (admin@datacycle.at) does NOT inherit it. TestPreparations seeds the
          # user; it carries no token, and the around(:all) transaction rolls this one back.
          @system_admin = DataCycleCore::User.find_by(email: 'system_admin@datacycle.at')
          @system_admin.update_column(:access_token, SecureRandom.hex)

          # lowest-ranked user available (guest, rank 0): proves the endpoints reject
          # authenticated non-admins, not just anonymous requests.
          @low_user = DataCycleCore::User.includes(:role).min_by { |u| u.role&.rank || Float::INFINITY }
          @low_user.update_column(:access_token, SecureRandom.hex)
        end

        # system_admin-only: the raw schema/config and the RDF schema
        RESTRICTED_ENDPOINTS = [
          '/api/config/schema',
          '/api/config/schema/some_template_name',
          '/api/config/common',
          '/api/config/feature',
          '/api/config/rdf/ontology',
          '/api/config/rdf/shapes',
          '/api/config/rdf/context'
        ].freeze

        # Authenticated but unrestricted: no subject is checked, so any logged-in user or
        # token reaches it. Still under the route-level `authenticate`, hence the anonymous
        # loop below covers it too.
        OPEN_ENDPOINTS = ['/api/config/openapi'].freeze

        # -------------------- anonymous is rejected everywhere --------------------
        # NOTE: the route-level `authenticate` throws :warden, so the body is written
        # by Warden's failure app (intercept_401) and is the same JSON:API error the
        # rest of the v4 API returns, not a message of our own. We assert that actual
        # contract here.
        #
        # We request JSON explicitly: /api/config/openapi is dual-served — browser
        # requests (Accept: text/html) get the interactive viewer (a login-gated UI
        # page that redirects anonymous users to sign-in), while API clients get the
        # JSON document behind the route-level `authenticate`. This test exercises the
        # API auth guard, so it must ask for JSON.
        (RESTRICTED_ENDPOINTS + OPEN_ENDPOINTS).each do |path|
          test "GET #{path} without authentication returns 401" do
            get path, headers: { 'Accept' => 'application/json' }

            assert_response :unauthorized
            assert_equal 'application/json; charset=utf-8', response.content_type
            assert_equal 'invalid or missing authentication token', response.parsed_body.dig('errors', 0, 'detail')
          end
        end

        # -------------------- openapi + rdf: system_admin passes --------------------
        # The JSON document (OpenapiController#index) — request JSON explicitly, since
        # the endpoint is dual-served (an HTML Accept yields the viewer page instead).
        test 'GET /api/config/openapi with a system_admin token returns the OpenAPI document' do
          get '/api/config/openapi', params: { token: @system_admin.access_token }, headers: { 'Accept' => 'application/json' }

          assert_response :success
          # body carries the generated OpenAPI document; assert on the version
          # marker of the 3.1 skeleton (openapi: "3.1.0")
          assert_includes response.body, '3.1.0'
        end

        # The interactive viewer (OpenApiViewerController#show) via a browser session
        # (HTML Accept). It checks no subject; a system_admin is simply one signed-in user.
        test 'GET /api/config/openapi (viewer) with a system_admin session succeeds' do
          sign_in(@system_admin)

          get '/api/config/openapi'

          assert_response :success
          assert_includes response.body, 'swagger-ui'
        ensure
          sign_out(@system_admin)
        end

        test 'GET /api/config/rdf/ontology with a system_admin token returns the ontology' do
          get '/api/config/rdf/ontology.ttl', params: { token: @system_admin.access_token }

          assert_response :success
          assert_equal 'text/turtle', response.media_type
        end

        # The viewer carries no authorize!, so being signed in is enough — a non-admin gets
        # the same page a system_admin does.
        test 'GET /api/config/openapi (viewer) with a low-privilege session renders the viewer' do
          sign_in(@low_user)

          get '/api/config/openapi', headers: { 'Accept' => 'text/html' }

          assert_response :success
          assert_includes response.body.to_s, 'swagger-ui'
        ensure
          sign_out(@low_user)
        end

        # -------------------- restricted endpoints: system_admin passes --------------------
        test 'GET /api/config/schema with a system_admin token returns the schema graph' do
          get '/api/config/schema', params: { token: @system_admin.access_token }

          assert_response :success
          assert response.parsed_body.key?('@graph')
        end

        test 'GET /api/config/schema/:template_name with a system_admin token passes auth (404 for unknown template)' do
          get '/api/config/schema/does_not_exist', params: { token: @system_admin.access_token }

          # reaching the not-found branch proves the route-level authenticate + authorize! let us through
          assert_response :not_found
          assert_includes response.parsed_body['error'], 'does_not_exist'
        end

        test 'GET /api/config/common with a system_admin token returns the common config' do
          get '/api/config/common', params: { token: @system_admin.access_token }

          assert_response :success
          assert response.parsed_body.key?('@graph')
        end

        test 'GET /api/config/feature with a system_admin token returns the feature config' do
          get '/api/config/feature', params: { token: @system_admin.access_token }

          assert_response :success
          assert response.parsed_body.key?('@graph')
        end

        test 'GET /api/config/schema with a system_admin session succeeds' do
          sign_in(@system_admin)

          get '/api/config/schema'

          assert_response :success
        ensure
          sign_out(@system_admin)
        end

        # -------------------- restricted endpoints: non-system_admin is rejected --------------------
        # A denied authorize! raises CanCan::AccessDenied, which ErrorHandler maps to
        # :unauthorized (401) outside development — the same status as the anonymous
        # case. We assert 401 (not 403) for a low-privilege but authenticated user.
        # JSON is requested explicitly for the same reason as in the anonymous loop:
        # /api/config/openapi is dual-served, and an HTML Accept would reach the viewer
        # page (a UI controller that redirects) instead of the API endpoint under test.
        OPEN_ENDPOINTS.each do |path|
          test "GET #{path} with a low-privilege token returns the document" do
            get path, params: { token: @low_user.access_token }, headers: { 'Accept' => 'application/json' }

            assert_response :success,
                            "#{path} must be open to any authenticated user, but got #{response.status}"
          end
        end

        RESTRICTED_ENDPOINTS.each do |path|
          test "GET #{path} with a low-privilege token is rejected with 401" do
            get path, params: { token: @low_user.access_token }, headers: { 'Accept' => 'application/json' }

            assert_response :unauthorized,
                            "#{path} must be system_admin-only, but a low-privilege user got #{response.status}"
          end
        end
      end
    end
  end
end
