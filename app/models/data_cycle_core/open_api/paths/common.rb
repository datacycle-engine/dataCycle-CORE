# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # Shared building blocks for the v4 path definitions: reusable parameter
      # reference lists, the JSON-LD envelope response, the ContentQuery request
      # body and the standard error responses. Keeps the individual path files
      # (classifications, collections, …) DRY.
      #
      # Path keys are relative to the `/api/v4` server base (set by the
      # DocumentBuilder). The optional `(/:api_subversion)` route prefix is not
      # expressed as a path template (OpenAPI has no optional path params); it is
      # absorbed by the server base URL.
      module Common
        module_function

        extend DataCycleCore::OpenApi::Localizable

        JSON_MEDIA_TYPE = 'application/json'

        # $refs shared by list (collection) operations, in the canonical order
        # (see Components::Parameters#all). `filter` is prepended in #list_parameters.
        LIST_PARAM_NAMES = [
          'fields', 'include', 'classificationTrees', 'language', 'sort', 'pageSize', 'pageNumber', 'pageOffset', 'pageLimit', 'sectionGraph', 'sectionContext', 'sectionMeta', 'sectionLinks', 'token'
        ].freeze

        # $refs shared by single-resource operations (canonical order).
        SINGLE_PARAM_NAMES = [
          'fields', 'include', 'language', 'sectionGraph', 'sectionContext', 'sectionMeta', 'sectionLinks', 'token'
        ].freeze

        # Parameter reference objects for a list operation (optionally incl. filter).
        # `filter` leads — it is the central query parameter.
        def list_parameters(with_filter: true)
          refs = LIST_PARAM_NAMES.map { |n| parameter_ref(n) }
          refs.unshift(parameter_ref('filter')) if with_filter
          refs
        end

        # Parameter reference objects for a single-resource operation.
        def single_parameters
          SINGLE_PARAM_NAMES.map { |n| parameter_ref(n) }
        end

        # A #/components/parameters reference.
        def parameter_ref(name)
          { '$ref' => "#/components/parameters/#{name}" }
        end

        # A required UUID path parameter.
        def id_path_param(name, description)
          {
            'name' => name,
            'in' => 'path',
            'required' => true,
            'description' => description,
            'schema' => { 'type' => 'string', 'format' => 'uuid' }
          }
        end

        # The standard error responses (400/401/404) as $refs, shared by every
        # operation (content and non-content alike). Invalid parameters raise
        # BadRequestError -> 400 (ErrorHandler#bad_request_api_error); missing/invalid
        # auth -> 401; unknown resource -> 404. CanCan::AccessDenied is rescued to
        # :unauthorized (401), not 403 (see DataCycleCore::ErrorHandler), so the API
        # never returns 403.
        def error_responses
          {
            '400' => { '$ref' => '#/components/responses/BadRequest' },
            '401' => { '$ref' => '#/components/responses/Unauthorized' },
            '404' => { '$ref' => '#/components/responses/NotFound' }
          }
        end

        # 200 JSON-LD envelope response. References the shared JsonLdEnvelope
        # directly so the schema shown under every response is identical to the
        # JsonLdEnvelope in the Schemas list. (Per-endpoint @graph narrowing was
        # dropped: it made the response schema differ from the list — the point of
        # this method is a single, consistent envelope everywhere.)
        def envelope_response(description)
          {
            'description' => description,
            'content' => { JSON_MEDIA_TYPE => { 'schema' => { '$ref' => '#/components/schemas/JsonLdEnvelope' } } }
          }
        end

        # $refs for a single-resource content operation (no paging/sort/filter),
        # i.e. the delivery parameters #show actually evaluates.
        def delivery_parameters
          ['fields', 'include', 'dcLiveData', 'classificationTrees', 'language', 'token'].map { |n| parameter_ref(n) }
        end

        # A required string path parameter (non-UUID: attribute/timeseries names, keys).
        def string_path_param(name, description, example: nil)
          schema = { 'type' => 'string' }
          schema['example'] = example unless example.nil?
          {
            'name' => name,
            'in' => 'path',
            'required' => true,
            'description' => description,
            'schema' => schema
          }
        end

        # `groupBy` query parameter (aggregation bucket), shared by the statistics
        # and timeseries operations (Api::V4::ContentsController#statistics_params /
        # #timeseries_params both permit it). `enum` narrows it to the fixed
        # time-bucket names for statistics; left free-form for timeseries, which
        # additionally accepts an aggregate-function prefix (sum_/min_/max_/avg_).
        def group_by_parameter(description, enum: nil)
          schema = { 'type' => 'string' }
          schema['enum'] = enum if enum
          {
            'name' => 'groupBy',
            'in' => 'query',
            'required' => false,
            'description' => description,
            'schema' => schema
          }
        end

        # `groupBy`/`time` query parameters shared by the endpoint- and thing-scoped
        # timeseries operations (Paths::Delivery#timeseries_params,
        # Paths::Contents#timeseries_params) -- both back onto the same
        # ContentsController#timeseries_params, so their OpenAPI representation is
        # identical.
        def timeseries_query_parameters
          [
            group_by_parameter(t('paths.common.timeseries_group_by')),
            time_parameter(t('paths.common.timeseries_time'))
          ]
        end

        # `time` range query parameter (`{in: {min, max}}`, deepObject), shared by
        # the statistics and timeseries operations to bound the aggregation
        # window. Same `{in: {min, max}}` shape as ScheduleFilter's `in` predicate
        # (Schemas::Filters::Predicates#schedule_filter), but kept separate: these
        # operations filter a raw SQL time column directly, not a recursive
        # content filter.
        def time_parameter(description)
          {
            'name' => 'time',
            'in' => 'query',
            'required' => false,
            'style' => 'deepObject',
            'explode' => true,
            'description' => description,
            'schema' => {
              'type' => 'object',
              'properties' => {
                'in' => {
                  'type' => 'object',
                  'properties' => {
                    'min' => { 'type' => 'string', 'description' => t('filter.min_max') },
                    'max' => { 'type' => 'string', 'description' => t('filter.min_max') }
                  }
                }
              }
            }
          }
        end

        # POST request body mirroring the GET query/filter parameters.
        def filter_request_body
          {
            'required' => false,
            'content' => {
              JSON_MEDIA_TYPE => { 'schema' => { '$ref' => '#/components/schemas/ContentQuery' } }
            }
          }
        end

        # POST body mirroring the delivery query parameters (no filter).
        def delivery_request_body
          {
            'required' => false,
            'content' => {
              JSON_MEDIA_TYPE => { 'schema' => { '$ref' => '#/components/schemas/DeliveryParams' } }
            }
          }
        end

        # 200 response for a downloadable file (binary or CSV).
        def file_response(description)
          {
            'description' => description,
            'content' => {
              'application/octet-stream' => { 'schema' => { 'type' => 'string', 'format' => 'binary' } },
              'text/csv' => { 'schema' => { 'type' => 'string' } }
            }
          }
        end

        # 200 response with a JSON object body. `schema` defaults to a generic
        # object; pass a concrete schema (inline hash or $ref) to document the
        # actual response shape (statistics, elevation profile, facets, …).
        def json_object_response(description, schema: nil)
          {
            'description' => description,
            'content' => { JSON_MEDIA_TYPE => { 'schema' => schema || { 'type' => 'object' } } }
          }
        end

        # 200 response selectable as JSON or CSV (for explicit /{format} routes).
        # `schema` documents the JSON body (CSV is always plain text).
        def json_csv_response(description, schema: nil)
          {
            'description' => description,
            'content' => {
              JSON_MEDIA_TYPE => { 'schema' => schema || { 'type' => 'object' } },
              'text/csv' => { 'schema' => { 'type' => 'string' } }
            }
          }
        end

        # 302 redirect response with a Location header.
        def redirect_response(description)
          {
            'description' => description,
            'headers' => {
              'Location' => {
                'description' => t('paths.common.redirect_location'),
                'schema' => { 'type' => 'string', 'format' => 'uri' }
              }
            }
          }
        end

        # Assemble a single operation object.
        def operation(operation_id:, summary:, tags:, parameters:, responses:, request_body: nil)
          op = {
            'operationId' => operation_id,
            'summary' => summary,
            'tags' => tags,
            'parameters' => parameters,
            'responses' => responses
          }
          op['requestBody'] = request_body if request_body
          op
        end

        # Assemble a single write operation (POST/PUT/PATCH/DELETE). Unlike
        # #operation, `parameters` and `requestBody` are optional (omitted when
        # empty) and an optional `description` can carry role/permission notes.
        # `security` is only set to override the global requirement (e.g. []).
        def write_operation(operation_id:, summary:, tags:, responses:, parameters: [], request_body: nil, description: nil, security: nil)
          op = { 'operationId' => operation_id, 'summary' => summary, 'tags' => tags }
          op['description'] = description if description.present?
          op['parameters'] = parameters if parameters.present?
          op['requestBody'] = request_body if request_body
          op['responses'] = responses
          op['security'] = security unless security.nil?
          op
        end

        # A JSON request body wrapping the given schema (inline hash or $ref).
        def json_request_body(schema, required: true)
          {
            'required' => required,
            'content' => { JSON_MEDIA_TYPE => { 'schema' => schema } }
          }
        end

        # 200 response carrying the given schema (inline hash or $ref).
        def json_response(description, schema)
          {
            'description' => description,
            'content' => { JSON_MEDIA_TYPE => { 'schema' => schema } }
          }
        end

        # 201 Created response, optionally carrying a JSON body schema.
        def created_response(description, schema: nil)
          resp = { 'description' => description }
          resp['content'] = { JSON_MEDIA_TYPE => { 'schema' => schema } } if schema
          resp
        end

        # 202 Accepted response carrying a JSON object (async/queued work).
        # `schema` documents the concrete acknowledgement body when known.
        def accepted_response(description, schema: nil)
          json_object_response(description, schema:)
        end

        # 204 No Content response (no body).
        def no_content_response(description)
          { 'description' => description }
        end

        # The write-operation error set as $refs: 400 (invalid params/body),
        # 401 (missing/invalid auth; note CanCan::AccessDenied is rescued to 401,
        # never 403 — see DataCycleCore::ErrorHandler), 404 (unknown resource) and
        # 422 (model validation errors).
        def write_error_responses
          {
            '400' => { '$ref' => '#/components/responses/BadRequest' },
            '401' => { '$ref' => '#/components/responses/Unauthorized' },
            '404' => { '$ref' => '#/components/responses/NotFound' },
            '422' => { '$ref' => '#/components/responses/UnprocessableEntity' }
          }
        end

        # Assemble a GET+POST path item from a shared operation template.
        # operation_id is a PascalCase base; get/post ids are derived from it
        # (e.g. "ConceptSchemes" -> getConceptSchemes / postConceptSchemes).
        def read_path_item(operation_id:, summary:, tags:, parameters:, responses:)
          get_op = {
            'operationId' => "get#{operation_id}",
            'summary' => summary,
            'tags' => tags,
            'parameters' => parameters,
            'responses' => responses
          }
          post_op = get_op.merge('operationId' => "post#{operation_id}", 'requestBody' => filter_request_body)
          { 'get' => get_op, 'post' => post_op }
        end
      end
    end
  end
end
