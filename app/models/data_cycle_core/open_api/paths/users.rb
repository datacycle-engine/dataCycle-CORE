# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for the v4 user-management endpoints (config/routes.rb →
      # namespace :users, Api::V4::UsersController). Requires the UserApi feature.
      #   GET|POST  /users                 (index — current user context)
      #   GET|POST  /users/{id}            (show)
      #   POST      /users/create          (create)
      #   PATCH|PUT /users/update          (update — the current user)
      #   POST      /users/password        (request password reset)
      #   PATCH|PUT /users/password        (change password via reset token)
      #   POST      /users/resend_confirmation
      #   PATCH|PUT /users/confirm         (confirm via token)
      # Write operations require the corresponding ability (:create_user, :update,
      # :reset_password, :confirm); CanCan::AccessDenied is rescued to 401 (#50193).
      module Users
        module_function

        TAGS = ['Users'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/users' => index,
            '/users/create' => { 'post' => create },
            '/users/update' => update,
            '/users/password' => password_item,
            '/users/resend_confirmation' => { 'post' => resend_confirmation },
            '/users/confirm' => confirm,
            '/users/{id}' => show
          }
        end

        # GET|POST /users — current user plus accessible collections / stored filters.
        def index
          op = {
            'summary' => t('paths.users.index_summary'),
            'tags' => TAGS,
            'parameters' => [Common.parameter_ref('language'), Common.parameter_ref('token')],
            'responses' => { '200' => Common.json_object_response(t('paths.users.index_response'), schema: user_context) }.merge(Common.error_responses)
          }
          {
            'get' => op.merge('operationId' => 'getUsers'),
            'post' => op.merge('operationId' => 'postUsers')
          }
        end

        # GET|POST /users/{id} — a single user.
        def show
          op = {
            'summary' => t('paths.users.show_summary'),
            'tags' => TAGS,
            'parameters' => [Common.id_path_param('id', t('paths.users.show_id')), Common.parameter_ref('language'), Common.parameter_ref('token')],
            'responses' => { '200' => Common.json_response(t('paths.users.show_response'), user_object) }.merge(Common.error_responses)
          }
          {
            'get' => op.merge('operationId' => 'getUser'),
            'post' => op.merge('operationId' => 'postUser')
          }
        end

        # POST /users/create — create a user (requires :create_user).
        def create
          Common.write_operation(
            operation_id: 'createUser',
            summary: t('paths.users.create_summary'),
            description: t('paths.users.create_description'),
            tags: TAGS,
            request_body: Common.json_request_body(user_write_request),
            responses: {
              '201' => Common.created_response(t('paths.users.create_response'), schema: user_object)
            }.merge(Common.write_error_responses)
          )
        end

        # PATCH|PUT /users/update — update the authenticated user.
        def update
          op = Common.write_operation(
            operation_id: 'updateUser',
            summary: t('paths.users.update_summary'),
            description: t('paths.users.update_description'),
            tags: TAGS,
            request_body: Common.json_request_body(user_write_request),
            responses: { '200' => Common.json_response(t('paths.users.update_response'), user_object) }.merge(Common.write_error_responses)
          )
          { 'patch' => op, 'put' => op.merge('operationId' => 'putUser') }
        end

        # /users/password → POST requests a reset mail; PATCH|PUT sets a new
        # password via the reset token.
        def password_item
          change = Common.write_operation(
            operation_id: 'changePassword',
            summary: t('paths.users.change_password_summary'),
            tags: TAGS,
            request_body: Common.json_request_body(change_password_request),
            responses: { '200' => Common.json_response(t('paths.users.change_password_response'), user_object) }.merge(Common.write_error_responses)
          )
          {
            'post' => Common.write_operation(
              operation_id: 'requestPasswordReset',
              summary: t('paths.users.password_summary'),
              description: t('paths.users.password_description'),
              tags: TAGS,
              request_body: Common.json_request_body(password_request),
              responses: { '200' => Common.no_content_response(t('paths.users.password_response')) }.merge(Common.write_error_responses)
            ),
            'patch' => change,
            'put' => change.merge('operationId' => 'putChangePassword')
          }
        end

        # POST /users/resend_confirmation — resend the confirmation mail.
        def resend_confirmation
          Common.write_operation(
            operation_id: 'resendConfirmation',
            summary: t('paths.users.resend_confirmation_summary'),
            tags: TAGS,
            request_body: Common.json_request_body(email_request),
            responses: { '200' => Common.no_content_response(t('paths.users.resend_confirmation_response')) }.merge(Common.write_error_responses)
          )
        end

        # PATCH|PUT /users/confirm — confirm a user via the confirmation token.
        def confirm
          op = Common.write_operation(
            operation_id: 'confirmUser',
            summary: t('paths.users.confirm_summary'),
            tags: TAGS,
            request_body: Common.json_request_body(confirm_request),
            responses: { '200' => Common.no_content_response(t('paths.users.confirm_response')) }.merge(Common.write_error_responses)
          )
          { 'patch' => op, 'put' => op.merge('operationId' => 'putConfirmUser') }
        end

        # ---- schemas ---------------------------------------------------------

        # GET|POST /users index body: the JSON-LD envelope whose `@graph` carries
        # the current user's context (accessible watch lists + named stored
        # filters, the current user's email, the instance locales). See the
        # api/v4/users/index.jb view; `@graph` is omitted when section[@graph]=0.
        def user_context
          {
            'type' => 'object',
            'title' => 'UserContext',
            'properties' => {
              '@context' => { 'type' => 'object', 'additionalProperties' => true },
              '@graph' => {
                'type' => 'object',
                'properties' => {
                  '@type' => { 'type' => 'string', 'example' => 'dcls:User' },
                  'watchLists' => { 'type' => 'array', 'items' => { 'type' => 'object', 'properties' => { 'id' => { 'type' => 'string', 'format' => 'uuid' }, 'name' => { 'type' => 'string' }, 'path' => { 'type' => 'string' } } } },
                  'storedFilters' => { 'type' => 'array', 'items' => { 'type' => 'object', 'properties' => { 'id' => { 'type' => 'string', 'format' => 'uuid' }, 'name' => { 'type' => 'string' } } } },
                  'userData' => { 'type' => 'object', 'properties' => { 'email' => { 'type' => 'string', 'format' => 'email' } } },
                  'availableLocales' => { 'type' => 'array', 'items' => { 'type' => 'string' } }
                }
              }
            }
          }
        end

        # A user object as returned by the API. Concrete attributes depend on the
        # UserApi feature configuration, so extra properties are allowed; `token`
        # and `exp` are present on the create/update/change_password responses.
        def user_object
          {
            'type' => 'object',
            'title' => 'UserObject',
            'properties' => {
              'id' => { 'type' => 'string', 'format' => 'uuid' },
              'email' => { 'type' => 'string', 'format' => 'email' },
              'token' => { 'type' => 'string', 'description' => t('paths.users.field_token') },
              'exp' => { 'type' => 'integer', 'description' => t('paths.users.field_exp') }
            },
            'additionalProperties' => true
          }
        end

        # Create/update body. user_params are resolved dynamically from the
        # UserApi feature, so known keys are documented and extras are allowed.
        def user_write_request
          {
            'type' => 'object',
            'title' => 'UserWriteRequest',
            'properties' => {
              'email' => { 'type' => 'string', 'format' => 'email', 'description' => t('paths.users.field_email') },
              'password' => { 'type' => 'string', 'format' => 'password', 'description' => t('paths.users.field_password') },
              'passwordConfirmation' => { 'type' => 'string', 'format' => 'password', 'description' => t('paths.users.field_password_confirmation') },
              'name' => { 'type' => 'string' },
              'givenName' => { 'type' => 'string' },
              'familyName' => { 'type' => 'string' },
              'rank' => { 'type' => 'integer', 'description' => t('paths.users.field_rank') },
              'additional_attributes' => { 'type' => 'object', 'description' => t('paths.users.field_additional_attributes'), 'additionalProperties' => true }
            }.merge(layout_properties),
            'additionalProperties' => true
          }
        end

        # POST /users/password body (request reset mail).
        def password_request
          {
            'type' => 'object',
            'title' => 'PasswordResetRequest',
            'properties' => { 'email' => { 'type' => 'string', 'format' => 'email', 'description' => t('paths.users.field_email') } }.merge(layout_properties),
            'required' => ['email']
          }
        end

        # PATCH|PUT /users/password body (set new password).
        def change_password_request
          {
            'type' => 'object',
            'title' => 'ChangePasswordRequest',
            'properties' => {
              'password' => { 'type' => 'string', 'format' => 'password', 'description' => t('paths.users.field_password') },
              'passwordConfirmation' => { 'type' => 'string', 'format' => 'password', 'description' => t('paths.users.field_password_confirmation') },
              'resetPasswordToken' => { 'type' => 'string', 'description' => t('paths.users.field_reset_token') }
            },
            'required' => ['password', 'resetPasswordToken']
          }
        end

        # POST /users/resend_confirmation body.
        def email_request
          {
            'type' => 'object',
            'title' => 'EmailRequest',
            'properties' => { 'email' => { 'type' => 'string', 'format' => 'email', 'description' => t('paths.users.field_email') } }.merge(layout_properties),
            'required' => ['email']
          }
        end

        # PATCH|PUT /users/confirm body.
        def confirm_request
          {
            'type' => 'object',
            'title' => 'ConfirmRequest',
            'properties' => { 'confirmationToken' => { 'type' => 'string', 'description' => t('paths.users.field_confirmation_token') } },
            'required' => ['confirmationToken']
          }
        end

        # Layout/redirect properties shared by the write bodies (see
        # UsersController#layout_params / #password_params).
        def layout_properties
          {
            'mailerLayout' => { 'type' => 'string', 'description' => t('paths.users.field_layout') },
            'viewerLayout' => { 'type' => 'string', 'description' => t('paths.users.field_layout') },
            'redirectUrl' => { 'type' => 'string', 'format' => 'uri', 'description' => t('paths.users.field_redirect_url') },
            'forwardToUrl' => { 'type' => 'string', 'format' => 'uri', 'description' => t('paths.users.field_redirect_url') }
          }
        end
      end
    end
  end
end
