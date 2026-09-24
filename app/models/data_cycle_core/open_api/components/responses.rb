# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Components
      # Shared OpenAPI 3.1 response building blocks for the v4 read API:
      # the JSON-LD success envelope (schemas) and the reusable error
      # responses (components/responses).
      #
      # Shapes taken from the v4 renderer/handler:
      #   @context -> ThingRendererV4.api_plain_context
      #   meta     -> ThingRendererV4.api_plain_meta ({ total, pages, collection })
      #   links    -> ThingRendererV4.api_plain_links ({ prev, next })
      #   errors   -> ErrorHandler ({ errors: [{ source, detail, title? }] };
      #               `title` only on 400, source.parameter (400) vs source.pointer (401/404))
      module Responses
        module_function

        extend DataCycleCore::OpenApi::Localizable

        # An own constant and NOT a reference to Paths::Common: the Paths layer builds on
        # Components (Paths::Common references Components::Parameters), so the other direction
        # would be a dependency back into the calling layer.
        JSON_MEDIA_TYPE = 'application/json'

        # Envelope + error schemas, to be merged into components/schemas.
        # @graph is left as a generic object here; per-endpoint operations
        # pin its items to a concrete entity $ref (schemas from #47113).
        # @return [Hash{String=>Hash}]
        def schemas
          {
            'JsonLdContext' => json_ld_context,
            'EnvelopeMeta' => envelope_meta,
            'EnvelopeLinks' => envelope_links,
            'JsonLdEnvelope' => json_ld_envelope,
            'Error' => error,
            'ErrorEnvelope' => error_envelope
          }
        end

        # Reusable Response Objects, to be merged into components/responses.
        # @return [Hash{String=>Hash}]
        def all
          {
            'BadRequest' => error_response(t('responses.bad_request')),
            'Unauthorized' => error_response(t('responses.unauthorized')),
            'NotFound' => error_response(t('responses.not_found')),
            'Conflict' => error_response(t('responses.conflict')),
            'UnprocessableEntity' => error_response(t('responses.unprocessable_entity'))
          }
        end

        # JSON-LD @context: [ "https://schema.org/", { prefixes... } ].
        def json_ld_context
          {
            'type' => 'array',
            'title' => 'JsonLdContext',
            'description' => t('envelope.context'),
            'items' => {
              'oneOf' => [
                { 'type' => 'string', 'format' => 'uri' },
                { 'type' => 'object', 'additionalProperties' => { 'type' => 'string' } }
              ]
            }
          }
        end

        # meta section per ThingRendererV4.api_plain_meta.
        def envelope_meta
          {
            'type' => 'object',
            'title' => 'EnvelopeMeta',
            'properties' => {
              'total' => { 'type' => 'integer', 'description' => t('envelope.total') },
              'pages' => { 'type' => 'integer', 'description' => t('envelope.pages') },
              'collection' => {
                'type' => 'object',
                'description' => t('envelope.collection'),
                'properties' => {
                  'id' => { 'type' => 'string', 'format' => 'uuid' },
                  'name' => { 'type' => 'string' },
                  'slug' => { 'type' => 'string' },
                  'path' => { 'type' => 'string' }
                }
              }
            }
          }
        end

        # links section per ThingRendererV4.api_plain_links.
        def envelope_links
          {
            'type' => 'object',
            'title' => 'EnvelopeLinks',
            'properties' => {
              'prev' => { 'type' => 'string', 'format' => 'uri' },
              'next' => { 'type' => 'string', 'format' => 'uri' }
            }
          }
        end

        # The JSON-LD list envelope: @context + @graph + meta + links.
        def json_ld_envelope
          {
            'type' => 'object',
            'title' => 'JsonLdEnvelope',
            'description' => t('envelope.list'),
            'properties' => {
              '@context' => { '$ref' => '#/components/schemas/JsonLdContext' },
              '@graph' => {
                'type' => 'array',
                'items' => { 'type' => 'object' }
              },
              'meta' => { '$ref' => '#/components/schemas/EnvelopeMeta' },
              'links' => { '$ref' => '#/components/schemas/EnvelopeLinks' }
            }
          }
        end

        # A single JSON:API-style error object.
        def error
          {
            'type' => 'object',
            'title' => 'Error',
            'properties' => {
              'source' => {
                'type' => 'object',
                'description' => t('error.source'),
                'properties' => {
                  'parameter' => { 'type' => 'string', 'description' => t('error.parameter') },
                  'pointer' => { 'type' => 'string', 'description' => t('error.pointer') }
                }
              },
              'title' => { 'type' => 'string', 'description' => t('error.title') },
              'detail' => { 'type' => 'string', 'description' => t('error.detail') }
            },
            # Only `detail` is present on every error body; `title` is emitted only
            # by the 400/bad-request handler, `source.pointer` vs `source.parameter`
            # vary by handler (see DataCycleCore::ErrorHandler).
            'required' => ['detail']
          }
        end

        # The error envelope: { errors: [Error] }.
        def error_envelope
          {
            'type' => 'object',
            'title' => 'ErrorEnvelope',
            'properties' => {
              'errors' => {
                'type' => 'array',
                'items' => { '$ref' => '#/components/schemas/Error' }
              }
            },
            'required' => ['errors']
          }
        end

        # Build a Response Object carrying the error envelope.
        def error_response(description)
          {
            'description' => description,
            'content' => {
              JSON_MEDIA_TYPE => {
                'schema' => { '$ref' => '#/components/schemas/ErrorEnvelope' }
              }
            }
          }
        end
      end
    end
  end
end
