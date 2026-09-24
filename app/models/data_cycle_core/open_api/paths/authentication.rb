# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for the v4 authentication endpoints needed to obtain
      # and verify a token (config/routes.rb → namespace :authentication,
      # path: :auth; Api::V4::AuthenticationController):
      #   POST /auth/login              (email/password -> JWT)
      #   GET  /auth/check_credentials  (verify the presented credentials)
      #   POST /auth/renew_login        (exchange a valid token for a fresh one)
      #   POST /auth/logout             (invalidate the current token)
      # login + check_credentials are pulled forward from the write scope because
      # a token is a prerequisite for every other (secured) endpoint; renew_login
      # and logout complete the session lifecycle (#50193).
      module Authentication
        module_function

        TAGS = ['Authentication'].freeze
        # The media type lives in Paths::Common — an own constant beside it would state the same
        # thing twice (as in Paths::Contents, which uses Common::JSON_MEDIA_TYPE).
        JSON_MEDIA_TYPE = Common::JSON_MEDIA_TYPE

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/auth/login' => { 'post' => login },
            '/auth/check_credentials' => { 'get' => check_credentials },
            '/auth/renew_login' => { 'post' => renew_login },
            '/auth/logout' => { 'post' => logout }
          }
        end

        # POST /auth/login — exchange email/password for a JWT.
        # Public: credentials travel in the body, so global security is cleared.
        def login
          {
            'operationId' => 'login',
            'summary' => t('paths.authentication.login_summary'),
            'tags' => TAGS,
            'security' => [],
            'requestBody' => {
              'required' => true,
              'content' => {
                JSON_MEDIA_TYPE => { 'schema' => login_request }
              }
            },
            'responses' => {
              '200' => {
                'description' => t('paths.authentication.login_response'),
                'content' => { JSON_MEDIA_TYPE => { 'schema' => login_response } }
              },
              '400' => { '$ref' => '#/components/responses/BadRequest' },
              '401' => { '$ref' => '#/components/responses/Unauthorized' }
            }
          }
        end

        # GET /auth/check_credentials — verify the presented credentials.
        def check_credentials
          {
            'operationId' => 'checkCredentials',
            'summary' => t('paths.authentication.check_summary'),
            'description' => t('paths.authentication.check_description'),
            'tags' => TAGS,
            'responses' => {
              '200' => {
                'description' => t('paths.authentication.check_response'),
                'content' => {
                  JSON_MEDIA_TYPE => {
                    'schema' => {
                      'type' => 'object',
                      'properties' => { 'success' => { 'type' => 'boolean' } },
                      'required' => ['success']
                    }
                  }
                }
              },
              '401' => { '$ref' => '#/components/responses/Unauthorized' }
            }
          }
        end

        # POST /auth/renew_login — exchange the presented (still valid) token for
        # a fresh one. The current token travels in the Authorization header /
        # token query (global security), so there is no request body.
        def renew_login
          {
            'operationId' => 'renewLogin',
            'summary' => t('paths.authentication.renew_summary'),
            'description' => t('paths.authentication.renew_description'),
            'tags' => TAGS,
            'responses' => {
              '200' => {
                'description' => t('paths.authentication.renew_response'),
                'content' => { JSON_MEDIA_TYPE => { 'schema' => login_response } }
              },
              '401' => { '$ref' => '#/components/responses/Unauthorized' }
            }
          }
        end

        # POST /auth/logout — invalidate the current token (clears the user's jti).
        def logout
          {
            'operationId' => 'logout',
            'summary' => t('paths.authentication.logout_summary'),
            'tags' => TAGS,
            'responses' => {
              '204' => { 'description' => t('paths.authentication.logout_response') },
              '401' => { '$ref' => '#/components/responses/Unauthorized' }
            }
          }
        end

        # Request body of POST /auth/login.
        def login_request
          {
            'type' => 'object',
            'title' => 'LoginRequest',
            'properties' => {
              'email' => { 'type' => 'string', 'format' => 'email' },
              'password' => { 'type' => 'string', 'format' => 'password' },
              'iss' => { 'type' => 'string', 'description' => t('paths.authentication.login_iss') },
              'original_iss' => { 'type' => 'string', 'description' => t('paths.authentication.login_original_iss') }
            },
            'required' => ['email', 'password']
          }
        end

        # 200 response body of POST /auth/login.
        def login_response
          {
            'type' => 'object',
            'title' => 'LoginResponse',
            'properties' => {
              'token' => { 'type' => 'string', 'description' => t('paths.authentication.login_token') },
              'exp' => { 'type' => 'integer', 'description' => t('paths.authentication.login_exp') },
              'user' => {
                'type' => 'object',
                'description' => t('paths.authentication.login_user'),
                'additionalProperties' => true
              }
            },
            'required' => ['token']
          }
        end
      end
    end
  end
end
