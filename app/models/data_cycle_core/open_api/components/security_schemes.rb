# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Components
      # OpenAPI 3.1 components/securitySchemes for the v4 API.
      #
      # The v4 API authenticates via a JSON Web Token sent either as an
      # `Authorization: Bearer <jwt>` header (see Api::V4::AuthenticationController
      # / JsonWebToken) or as a `token` query parameter. (Email/password is only
      # accepted as the request body of POST /auth/login, not as an HTTP Basic
      # header — see DataCycleCore::EmailPasswordStrategy — so it is not a global
      # security scheme.)
      module SecuritySchemes
        module_function

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] name => OpenAPI security scheme object,
        #   ready to be merged into components/securitySchemes.
        def all
          {
            'bearerAuth' => {
              'type' => 'http',
              'scheme' => 'bearer',
              'bearerFormat' => 'JWT',
              'description' => t('security.bearer')
            },
            'tokenQuery' => {
              'type' => 'apiKey',
              'in' => 'query',
              'name' => 'token',
              'description' => t('security.token_query')
            }
          }
        end

        # Global security requirement: any one of the supported schemes suffices.
        # @return [Array<Hash>]
        def global_security
          [
            { 'bearerAuth' => [] },
            { 'tokenQuery' => [] }
          ]
        end
      end
    end
  end
end
