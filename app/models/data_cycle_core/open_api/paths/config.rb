# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for the config/meta endpoints (config/routes.rb →
      # namespace :config, Api::Config::{Schema,Common,Feature}Controller):
      #   GET|POST /config/schema(/{template_name})
      #   GET|POST /config/common
      #   GET|POST /config/feature
      #   GET      /config/openapi   (this document)
      # These live under /api/config (a sibling of /api/v4, NOT below it), so every
      # path item carries its own /api/config server override (#50193).
      module Config
        module_function

        TAGS = ['Config'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # Server override shared by all config path items.
        def server
          [{ 'url' => '/api/config', 'description' => t('paths.config.server') }]
        end

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/schema' => with_server(read_item('Schema', t('paths.config.schema_index_summary'), t('paths.config.schema_index_response'))),
            '/schema/{template_name}' => with_server(read_item('SchemaTemplate', t('paths.config.schema_show_summary'), t('paths.config.schema_show_response'), extra_params: [Common.string_path_param('template_name', t('paths.config.template_name'))], errors: Common.error_responses)),
            '/common' => with_server(read_item('CommonConfig', t('paths.config.common_summary'), t('paths.config.common_response'))),
            '/feature' => with_server(read_item('FeatureConfig', t('paths.config.feature_summary'), t('paths.config.feature_response'))),
            '/openapi' => with_server('get' => openapi)
          }
        end

        # Prepend the config server override to a path item.
        def with_server(item)
          { 'servers' => server }.merge(item)
        end

        # A GET+POST config read operation returning a JSON-LD envelope.
        def read_item(base, summary, response_description, extra_params: [], errors: nil)
          params = extra_params + [Common.parameter_ref('token')]
          responses = { '200' => Common.envelope_response(response_description) }.merge(errors || { '401' => { '$ref' => '#/components/responses/Unauthorized' } })
          op = { 'summary' => summary, 'tags' => TAGS, 'parameters' => params, 'responses' => responses }
          {
            'get' => op.merge('operationId' => "get#{base}"),
            'post' => op.merge('operationId' => "post#{base}")
          }
        end

        # GET /config/openapi — the generated OpenAPI document itself.
        def openapi
          {
            'operationId' => 'getOpenApi',
            'summary' => t('paths.config.openapi_summary'),
            'tags' => TAGS,
            'parameters' => [Common.parameter_ref('language')],
            'responses' => {
              '200' => Common.json_object_response(t('paths.config.openapi_response'), schema: openapi_document)
            }
          }
        end

        # Top-level shape of the generated OpenAPI 3.1 document (see
        # OpenApi::DocumentBuilder#call). `paths`/`components` are open objects —
        # their inner shape is the whole rest of this specification.
        def openapi_document
          {
            'type' => 'object',
            'title' => 'OpenApiDocument',
            'properties' => {
              'openapi' => { 'type' => 'string', 'example' => '3.1.0' },
              'info' => { 'type' => 'object', 'properties' => { 'title' => { 'type' => 'string' }, 'description' => { 'type' => 'string' }, 'version' => { 'type' => 'string' } } },
              'servers' => { 'type' => 'array', 'items' => { 'type' => 'object', 'properties' => { 'url' => { 'type' => 'string' }, 'description' => { 'type' => 'string' } } } },
              'security' => { 'type' => 'array', 'items' => { 'type' => 'object', 'additionalProperties' => true } },
              'tags' => { 'type' => 'array', 'items' => { 'type' => 'object', 'properties' => { 'name' => { 'type' => 'string' } }, 'additionalProperties' => true } },
              'paths' => { 'type' => 'object', 'additionalProperties' => true },
              'components' => {
                'type' => 'object',
                'properties' => {
                  'schemas' => { 'type' => 'object', 'additionalProperties' => true },
                  'parameters' => { 'type' => 'object', 'additionalProperties' => true },
                  'responses' => { 'type' => 'object', 'additionalProperties' => true },
                  'securitySchemes' => { 'type' => 'object', 'additionalProperties' => true }
                }
              }
            },
            'additionalProperties' => true
          }
        end
      end
    end
  end
end
