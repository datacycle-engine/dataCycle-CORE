# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for the content-scoped external-connection endpoints
      # (config/routes.rb -> Api::V4::ExternalConnectionsController): add and remove a
      # connection, promote one to the primary external system and demote the primary
      # one. Documented in docs/api/contents/external_connections.md.
      #
      # A connection is addressed by the `propertyID`/`value` pair the API already
      # publishes under `identifier`, so no internal sync id appears in the contract.
      # Only `duplicate`-type connections are writable; `import`/`export` ones belong
      # to the import resp. export machinery and are rejected with 422.
      #
      # Not to be confused with PATCH /external_sources/{external_source_id}/demote
      # (Paths::ExternalSources#demote), where an importing system bulk-demotes its
      # own contents.
      module ExternalConnections
        module_function

        TAGS = ['External Connections'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/things/{id}/external_connections' => { 'post' => create, 'delete' => destroy },
            '/things/{id}/external_connections/promote' => { 'patch' => promote },
            '/things/{id}/external_connections/demote' => { 'patch' => demote }
          }
        end

        # ---- shared path parameters -----------------------------------------

        # Path parameter for the addressed content.
        def id_param
          Common.id_path_param('id', t('paths.external_connections.id'))
        end

        # ---- operations ------------------------------------------------------

        # POST -- add a `duplicate` connection. Idempotent; 422 when an import/export
        # already holds the same propertyID/value pair.
        def create
          connection_operation(
            operation_id: 'createThingExternalConnection',
            summary: t('paths.external_connections.create_summary'),
            description: t('paths.external_connections.create_description'),
            request_body: Common.json_request_body(connection_request)
          )
        end

        # DELETE -- remove a `duplicate` connection. Idempotent, so the pair is passed
        # as query parameters and no body is required.
        def destroy
          connection_operation(
            operation_id: 'deleteThingExternalConnection',
            summary: t('paths.external_connections.destroy_summary'),
            description: t('paths.external_connections.destroy_description'),
            parameters: [id_param, *pair_query_parameters]
          )
        end

        # PATCH /promote -- make an existing connection the primary external system.
        # 409 when another content already uses that external key as its primary.
        def promote
          connection_operation(
            operation_id: 'promoteThingExternalConnection',
            summary: t('paths.external_connections.promote_summary'),
            description: t('paths.external_connections.promote_description'),
            request_body: Common.json_request_body(connection_request),
            extra_responses: { '409' => { '$ref' => '#/components/responses/Conflict' } }
          )
        end

        # PATCH /demote -- turn the primary external system into a `duplicate`
        # connection. Addresses no pair, so it takes no body.
        def demote
          connection_operation(
            operation_id: 'demoteThingExternalConnection',
            summary: t('paths.external_connections.demote_summary'),
            description: t('paths.external_connections.demote_description')
          )
        end

        # ---- shared operation shape -----------------------------------------

        # All four operations answer with the content's full connection state, so a
        # client never needs a second request to read it back.
        def connection_operation(operation_id:, summary:, description:, parameters: [id_param], request_body: nil, extra_responses: {})
          Common.write_operation(
            operation_id:,
            summary:,
            description:,
            tags: TAGS,
            parameters:,
            request_body:,
            # sorted by status code: the viewer lists responses in insertion order, so an
            # appended extra_responses entry (409) would otherwise show up after the 422
            responses: { '200' => Common.json_response(t('paths.external_connections.response'), body_schema) }
                .merge(Common.write_error_responses)
                .merge(extra_responses)
                .sort.to_h
          )
        end

        # ---- parameters / bodies --------------------------------------------

        # The addressed connection as query parameters (DELETE).
        def pair_query_parameters
          [
            Components::Parameters.query_string('propertyID', t('paths.external_connections.property_id'), required: true),
            Components::Parameters.query_string('value', t('paths.external_connections.value'), required: true)
          ]
        end

        # The addressed connection as a JSON body (POST/PATCH promote).
        def connection_request
          {
            'type' => 'object',
            'title' => 'ExternalConnectionRequest',
            'required' => ['propertyID', 'value'],
            'properties' => {
              'propertyID' => { 'type' => 'string', 'description' => t('paths.external_connections.property_id') },
              'value' => { 'type' => 'string', 'description' => t('paths.external_connections.value') }
            }
          }
        end

        # Inlined rather than registered as a component, the way the other
        # non-envelope bodies are handled (Schemas::ResponseBodies).
        def body_schema
          DataCycleCore::OpenApi::Schemas::ResponseBodies.external_connection_collection
        end
      end
    end
  end
end
