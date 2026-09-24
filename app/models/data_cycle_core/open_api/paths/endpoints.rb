# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for /endpoints (config/routes.rb -> stored_filters#index / #create):
      #   GET /endpoints  -- list the api: true StoredFilters visible to the current user.
      #   POST /endpoints -- create a collection/stored filter from a source endpoint (#50193).
      module Endpoints
        module_function

        TAGS = ['Endpoints'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          { '/endpoints' => endpoints.merge('post' => create) }
        end

        # GET /endpoints -- list of accessible data endpoints.
        def endpoints
          {
            'get' => Common.operation(
              operation_id: 'getEndpoints',
              summary: t('paths.endpoints.endpoints_summary'),
              tags: DataCycleCore::OpenApi::Paths::Delivery::TAGS,
              parameters: Common.list_parameters(with_filter: false),
              responses: {
                '200' => Common.envelope_response(t('paths.endpoints.endpoints_response'))
              }.merge(Common.error_responses)
            )
          }
        end

        # POST /endpoints — create a collection/stored filter from a source
        # endpoint and the given content query. Renders a JSON-LD document with
        # the created collection (HTTP 201).
        def create
          Common.write_operation(
            operation_id: 'createEndpoint',
            summary: t('paths.endpoints.create_summary'),
            description: t('paths.endpoints.create_description'),
            tags: TAGS,
            request_body: Common.json_request_body(create_request),
            responses: {
              '201' => Common.created_response(t('paths.endpoints.create_response'), schema: { '$ref' => '#/components/schemas/JsonLdEnvelope' })
            }.merge(Common.write_error_responses)
          )
        end

        # Request body of POST /endpoints: the content query (ContentQuery) plus
        # the source `endpoint` and optional `collection` metadata.
        def create_request
          {
            'title' => 'EndpointCreateRequest',
            'allOf' => [
              { '$ref' => '#/components/schemas/ContentQuery' },
              {
                'type' => 'object',
                'properties' => {
                  'endpoint' => { 'type' => 'string', 'description' => t('paths.endpoints.endpoint_ref') },
                  'collection' => {
                    'type' => 'object',
                    'description' => t('paths.endpoints.collection_desc'),
                    'properties' => {
                      '@type' => { 'type' => 'string', 'description' => t('paths.endpoints.collection_type') },
                      'name' => { 'type' => 'string', 'description' => t('paths.endpoints.collection_name') },
                      'validFrom' => { 'type' => 'string', 'format' => 'date-time', 'description' => t('paths.endpoints.collection_valid_from') },
                      'validUntil' => { 'type' => 'string', 'format' => 'date-time', 'description' => t('paths.endpoints.collection_valid_until') }
                    }
                  }
                },
                'required' => ['endpoint']
              }
            ]
          }
        end
      end
    end
  end
end
