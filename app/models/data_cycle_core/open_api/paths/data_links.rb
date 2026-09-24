# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 path for the v4 external-link (data link) endpoint
      # (config/routes.rb → `resources :data_links, path: :external_links`,
      # Api::V4::DataLinksController#create):
      #   POST /external_links
      # The request body mirrors DataLinksController::DATALINK_PARAMS_SCHEMA (#50193).
      module DataLinks
        module_function

        TAGS = ['External Links'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/external_links' => { 'post' => create }
          }
        end

        # POST /external_links — grant one or more users access to contents. Each
        # entry is processed independently: HTTP 201 when all succeed, 207 when
        # some entries failed (per-entry success flag + errors[]).
        def create
          Common.write_operation(
            operation_id: 'createExternalLinks',
            summary: t('paths.data_links.create_summary'),
            description: t('paths.data_links.create_description'),
            tags: TAGS,
            request_body: Common.json_request_body(create_request),
            responses: {
              '201' => Common.json_response(t('paths.data_links.create_response'), create_response),
              '207' => Common.json_response(t('paths.data_links.multi_status_response'), create_response)
            }.merge(Common.write_error_responses)
          )
        end

        # Request body: { "@graph": [ { receiver, item, permission, ... } ] }.
        def create_request
          {
            'type' => 'object',
            'title' => 'ExternalLinkCreateRequest',
            'properties' => {
              '@graph' => {
                'type' => 'array',
                'minItems' => 1,
                'description' => t('paths.data_links.graph_desc'),
                'items' => data_link_entry
              }
            },
            'required' => ['@graph']
          }
        end

        # A single external-link entry.
        def data_link_entry
          {
            'type' => 'object',
            'title' => 'ExternalLinkEntry',
            'properties' => {
              'receiver' => {
                'type' => 'object',
                'description' => t('paths.data_links.receiver_desc'),
                'properties' => {
                  'email' => { 'type' => 'string', 'format' => 'email' },
                  'givenName' => { 'type' => 'string' },
                  'familyName' => { 'type' => 'string' },
                  'name' => { 'type' => 'string' }
                },
                'required' => ['email']
              },
              'item' => {
                'type' => 'object',
                'description' => t('paths.data_links.item_desc'),
                'properties' => {
                  '@id' => { 'type' => 'string', 'format' => 'uuid' },
                  '@type' => { 'type' => 'string', 'enum' => ['Thing'], 'default' => 'Thing' }
                },
                'required' => ['@id']
              },
              'permission' => { 'type' => 'string', 'enum' => permission_values, 'description' => t('paths.data_links.permission_desc') },
              'comment' => { 'type' => 'string', 'description' => t('paths.data_links.comment_desc') },
              'validFrom' => { 'type' => 'string', 'format' => 'date-time', 'description' => t('paths.data_links.valid_from_desc') },
              'validUntil' => { 'type' => 'string', 'format' => 'date-time', 'description' => t('paths.data_links.valid_until_desc') }
            },
            'required' => ['receiver', 'item', 'permission']
          }
        end

        # 201/207 response: per-entry results plus the shared errors[] envelope.
        def create_response
          {
            'type' => 'object',
            'title' => 'ExternalLinkCreateResponse',
            'properties' => {
              '@graph' => {
                'type' => 'array',
                'items' => {
                  'type' => 'object',
                  'properties' => {
                    'success' => { 'type' => 'boolean' },
                    '@id' => { 'type' => 'string', 'format' => 'uuid' },
                    'url' => { 'type' => 'string', 'format' => 'uri' }
                  }
                }
              },
              'errors' => { 'type' => 'array', 'items' => { '$ref' => '#/components/schemas/Error' } }
            }
          }
        end

        # Allowed permission values, read from the model so the enum can never
        # drift from DataLink::PERMISSIONS.
        def permission_values
          DataCycleCore::DataLink::PERMISSIONS.values
        end
      end
    end
  end
end
