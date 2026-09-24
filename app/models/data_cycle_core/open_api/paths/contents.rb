# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for the v4 content endpoints (routes.rb → things/universal),
      # ported from Emily's draft into the shared hash-based architecture.
      #   /things/{id}/{timeseries}(/{format})
      #   /things/select(/{uuids}), /things/deleted, /universal(/{id})
      # (the single-content /things/{id} read is intentionally not exposed)
      # All GET and POST. Path keys are relative to the /api/v4 server base;
      # the optional (/:api_subversion) route prefix is handled via the server.
      module Contents
        module_function

        TAGS = ['Contents'].freeze
        # The timeseries operations join the endpoint-scoped ones from
        # Paths::Delivery in one shared 'Timeseries' section.
        TAGS_TIMESERIES = ['Timeseries'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/things/{id}/{timeseries}' => thing_timeseries,
            '/things/{id}/{timeseries}/{format}' => thing_timeseries_format,
            '/things/select' => select,
            '/things/select/{uuids}' => select_by_path,
            '/things/deleted' => deleted,
            '/universal/{id}' => universal
            # /universal WITHOUT id is intentionally omitted: it always returns
            # 400 (no success response), so it is not a read endpoint.
          }
        end

        # GET/POST /things/{id}/{timeseries} — time series of one attribute.
        def thing_timeseries
          params = timeseries_params
          responses = { '200' => Common.json_object_response(t('paths.common.timeseries_data'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.timeseries_data) }.merge(Common.error_responses)
          get_post('getThingTimeseries', t('paths.contents.timeseries_summary'), params, responses, tags: TAGS_TIMESERIES)
        end

        # GET/POST /things/{id}/{timeseries}/{format} — time series with explicit format.
        def thing_timeseries_format
          params = timeseries_params + [Common.parameter_ref('format')]
          responses = { '200' => Common.json_csv_response(t('paths.common.timeseries_data_json_csv'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.timeseries_data) }.merge(Common.error_responses)
          get_post('getThingTimeseriesWithFormat', t('paths.contents.timeseries_format_summary'), params, responses, tags: TAGS_TIMESERIES)
        end

        # Path/query params shared by the timeseries operations.
        def timeseries_params
          [
            Common.id_path_param('id', t('paths.common.content_uuid')),
            Common.string_path_param('timeseries', t('paths.contents.timeseries_name'), example: 'measuredValue')
          ] + Common.delivery_parameters + Common.timeseries_query_parameters
        end

        # GET/POST /things/select — multiple contents by UUID list (query).
        def select
          params = [uuid_array_query, uuids_query] + Common.delivery_parameters
          responses = { '200' => Common.envelope_response(t('paths.contents.select_response')) }.merge(Common.error_responses)
          get_post('selectThings', t('paths.contents.select_summary'), params, responses, body: select_request_body)
        end

        # POST body for /things/select: the delivery params plus the UUID list the GET
        # carries as a query parameter (query params are stripped from POST bodies, so
        # the list must be expressible in the body for the POST variant). `uuid` is the
        # JSON array, `uuids` the comma-separated string: a JSON body has no bracket
        # spelling, so the array is named `uuid` here and `uuid[]` in the query.
        def select_request_body
          {
            'required' => false,
            'content' => {
              Common::JSON_MEDIA_TYPE => {
                'schema' => {
                  'allOf' => [
                    { '$ref' => '#/components/schemas/DeliveryParams' },
                    {
                      'type' => 'object',
                      'properties' => {
                        'uuid' => uuid_list_schema.merge('description' => t('paths.contents.uuid_query')),
                        'uuids' => { 'type' => 'string', 'description' => t('paths.contents.uuids_query') }
                      }
                    }
                  ]
                }
              }
            }
          }
        end

        # GET/POST /things/select/{uuids} — multiple contents by UUID list (path).
        def select_by_path
          params = [uuids_path_param] + Common.delivery_parameters
          responses = { '200' => Common.envelope_response(t('paths.contents.select_response')) }.merge(Common.error_responses)
          get_post('selectThingsByPath', t('paths.contents.select_by_path_summary'), params, responses)
        end

        # `uuid[]` query parameter for /things/select: one UUID per entry, and the spelling
        # ContentsController#select prefers when both are given. The brackets belong to the
        # name because Rack parses only that form into an array -- `uuid=a&uuid=b`, what
        # `style: form` produces for a bracket-less name, arrives as the single string "b".
        def uuid_array_query
          {
            'name' => 'uuid[]',
            'in' => 'query',
            'required' => false,
            'style' => 'form',
            'explode' => true,
            'description' => t('paths.contents.uuid_query'),
            'schema' => uuid_list_schema
          }
        end

        # `uuids` query parameter for /things/select: the same list as one value.
        # `explode: false` over an array IS the comma convention -- stated in the
        # parameter object it reaches a generated client, where prose would not.
        def uuids_query
          {
            'name' => 'uuids',
            'in' => 'query',
            'required' => false,
            'style' => 'form',
            'explode' => false,
            'description' => t('paths.contents.uuids_query'),
            'schema' => uuid_list_schema
          }
        end

        # `{uuids}` path segment of /things/select/{uuids}: the comma-separated list
        # again. `style: simple` with `explode: false` -- both the OpenAPI defaults for
        # a path parameter -- joins an array with commas, so the convention is carried
        # by the array schema alone.
        def uuids_path_param
          {
            'name' => 'uuids',
            'in' => 'path',
            'required' => true,
            'description' => t('paths.contents.uuids_path'),
            'schema' => uuid_list_schema
          }
        end

        # The one statement of the list's shape, shared by the three parameters that
        # spell it differently -- `uuid[]`, `uuids` and the `{uuids}` path segment
        # differ in their serialization, never in what they carry.
        def uuid_list_schema
          { 'type' => 'array', 'items' => { 'type' => 'string', 'format' => 'uuid' } }
        end

        # GET/POST /things/deleted — list deleted contents (filterable).
        def deleted
          responses = { '200' => Common.envelope_response(t('paths.contents.deleted_response')) }.merge(Common.error_responses)
          {
            'get' => Common.operation(operation_id: 'getDeletedThings', summary: t('paths.contents.deleted_summary'), tags: TAGS, parameters: Common.list_parameters, responses:),
            'post' => Common.operation(operation_id: 'getDeletedThingsViaPost', summary: "#{t('paths.contents.deleted_summary')}#{t('paths.common.via_post_suffix')}", tags: TAGS, parameters: Common.list_parameters(with_filter: false), responses:, request_body: Common.filter_request_body)
          }
        end

        # GET/POST /universal/{id} — resolve any resource by UUID (redirects).
        def universal
          params = [Common.id_path_param('id', t('paths.contents.universal_id'))]
          responses = { '302' => Common.redirect_response(t('paths.contents.universal_response')) }.merge(Common.error_responses)
          get_post('resolveUniversal', t('paths.contents.universal_summary'), params, responses)
        end

        # Build a GET+POST path item. POST carries a request body (delivery params
        # by default; pass `body:` to override, e.g. select adds `uuids`).
        def get_post(base, summary, parameters, responses, body: Common.delivery_request_body, tags: TAGS)
          {
            'get' => Common.operation(operation_id: base, summary:, tags:, parameters:, responses:),
            'post' => Common.operation(operation_id: "#{base}ViaPost", summary: "#{summary}#{t('paths.common.via_post_suffix')}", tags:, parameters:, responses:, request_body: body)
          }
        end
      end
    end
  end
end
