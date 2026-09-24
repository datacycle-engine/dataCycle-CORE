# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for the v4 external-source / external-system endpoints
      # (config/routes.rb → scope 'external_sources/:external_source_id',
      # Api::V4::ExternalSystemsController). Import/sync-heavy: create/update/delete
      # of contents, timeseries ingestion, concept & content lookup by external key
      # and the Feratel search/facet helpers (#50193).
      #
      # The write payloads are processed by per-system API strategies
      # (ExternalSystemsController#content_params permits a flexible @graph), so the
      # request/response schemas are intentionally generic.
      module ExternalSources
        module_function

        # Parent group plus sub-groups (rendered as nested items via x-parent in
        # DocumentBuilder#tags) so the large External Sources surface is split into
        # digestible sections instead of one flat list.
        TAGS = ['External Sources'].freeze
        TAGS_TIMESERIES = ['Timeseries Import'].freeze
        TAGS_LOOKUP = ['External Lookup'].freeze
        TAGS_FERATEL = ['Feratel'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/external_sources/{external_source_id}' => root_item,
            '/external_sources/{external_source_id}/demote' => { 'patch' => demote },
            '/external_sources/{external_source_id}/concepts' => concepts(with_key: false),
            '/external_sources/{external_source_id}/concepts/{external_key}' => concepts(with_key: true),
            '/external_sources/{external_source_id}/things/select' => things_select(with_keys: false),
            '/external_sources/{external_source_id}/things/select/{external_keys}' => things_select(with_keys: true),
            '/external_sources/{external_source_id}/search/availability' => search('AvailabilitySearch', t('paths.external_sources.search_availability_summary')),
            '/external_sources/{external_source_id}/search/additional_service' => search('AdditionalServiceSearch', t('paths.external_sources.search_additional_service_summary')),
            '/external_sources/{external_source_id}/facets/locations/{type}' => facets_locations,
            '/external_sources/{external_source_id}/{external_key}' => key_item,
            '/external_sources/{external_source_id}/{external_key}/timeseries' => put_patch('TimeseriesBulk', t('paths.external_sources.timeseries_bulk_summary'), [es_id, ext_key], timeseries_body, timeseries_responses),
            '/external_sources/{external_source_id}/{external_key}/timeseries/{attribute}' => put_patch('TimeseriesBulkAttr', t('paths.external_sources.timeseries_bulk_attr_summary'), [es_id, ext_key, attr_param], timeseries_body, timeseries_responses),
            '/external_sources/{external_source_id}/{external_key}/{attribute}' => put_patch('Timeseries', t('paths.external_sources.timeseries_summary'), [es_id, ext_key, attr_param], timeseries_body, timeseries_responses),
            '/external_sources/{external_source_id}/{external_key}/{attribute}/{format}' => put_patch('TimeseriesFormat', t('paths.external_sources.timeseries_format_summary'), [es_id, ext_key, attr_param, Common.parameter_ref('format')], timeseries_body, timeseries_responses)
          }
        end

        # ---- shared path parameters -----------------------------------------

        # $ref to the external_source_id path parameter.
        def es_id
          Common.parameter_ref('external_source_id')
        end

        # $ref to the external_key path parameter.
        def ext_key
          Common.parameter_ref('external_key')
        end

        # $ref to the attribute path parameter.
        def attr_param
          Common.parameter_ref('attribute')
        end

        # ---- create / update / delete (with & without external_key) ----------

        # POST create, PUT/PATCH update, DELETE destroy on the source root.
        def root_item
          {
            'post' => Common.write_operation(operation_id: 'createExternalSourceContent', summary: t('paths.external_sources.create_summary'), tags: TAGS, parameters: [es_id], request_body: Common.json_request_body(import_body), responses: import_responses),
            'put' => update_op('updateExternalSourceContent', [es_id]),
            'patch' => update_op('updateExternalSourceContentPatch', [es_id]),
            'delete' => destroy_op('deleteExternalSourceContent', [es_id])
          }
        end

        # GET/POST show (redirect to the resolved thing) plus update/destroy for a
        # specific external_key.
        def key_item
          params = [es_id, ext_key]
          show = {
            'summary' => t('paths.external_sources.show_summary'),
            'description' => t('paths.external_sources.show_description'),
            'tags' => TAGS,
            'parameters' => params,
            'responses' => { '302' => Common.redirect_response(t('paths.external_sources.show_response')) }.merge(Common.error_responses)
          }
          {
            'get' => show.merge('operationId' => 'getExternalSourceContentByKey'),
            'post' => show.merge('operationId' => 'postExternalSourceContentByKey'),
            'put' => update_op('updateExternalSourceContentByKey', params),
            'patch' => update_op('updateExternalSourceContentByKeyPatch', params),
            'delete' => destroy_op('deleteExternalSourceContentByKey', params)
          }
        end

        # PUT/PATCH update operation (with or without external_key).
        def update_op(operation_id, params)
          Common.write_operation(operation_id:, summary: t('paths.external_sources.update_summary'), tags: TAGS, parameters: params, request_body: Common.json_request_body(import_body), responses: import_responses)
        end

        # DELETE destroy operation (with or without external_key).
        def destroy_op(operation_id, params)
          Common.write_operation(operation_id:, summary: t('paths.external_sources.destroy_summary'), tags: TAGS, parameters: params, request_body: Common.json_request_body(import_body, required: false), responses: import_responses)
        end

        # PATCH /demote — demote the external system for the given contents.
        def demote
          Common.write_operation(operation_id: 'demoteExternalSource', summary: t('paths.external_sources.demote_summary'), tags: TAGS, parameters: [es_id], request_body: Common.json_request_body(import_body, required: false), responses: import_responses)
        end

        # ---- timeseries ingestion -------------------------------------------

        # PUT+PATCH builder for the timeseries endpoints (Timeseries Import group).
        def put_patch(base, summary, parameters, request_body, responses)
          op = ->(id) { Common.write_operation(operation_id: id, summary:, tags: TAGS_TIMESERIES, parameters:, request_body:, responses:) }
          { 'put' => op.call("put#{base}"), 'patch' => op.call("patch#{base}") }
        end

        # 202 (accepted) / 204 (no data) responses shared by the timeseries ops.
        def timeseries_responses
          { '202' => Common.accepted_response(t('paths.external_sources.timeseries_response'), schema: timeseries_import_result), '204' => Common.no_content_response(t('paths.external_sources.timeseries_empty_response')) }.merge(Common.write_error_responses)
        end

        # ---- concept / content lookup by external key -----------------------

        # GET|POST /concepts(/{external_key}) — concepts by external key.
        def concepts(with_key:)
          params = [es_id]
          params << ext_key if with_key
          get_post(with_key ? 'ExternalSourceConceptsByKey' : 'ExternalSourceConcepts', t('paths.external_sources.concepts_summary'), params, Common.envelope_response(t('paths.external_sources.concepts_response')), tags: TAGS_LOOKUP)
        end

        # GET|POST /things/select(/{external_keys}) — contents by external keys.
        def things_select(with_keys:)
          params = [es_id]
          params << Common.string_path_param('external_keys', t('paths.external_sources.external_keys')) if with_keys
          get_post(with_keys ? 'SelectByExternalKeys' : 'Select', t('paths.external_sources.select_summary'), params, Common.envelope_response(t('paths.external_sources.select_response')), tags: TAGS_LOOKUP)
        end

        # ---- Feratel search / facets ----------------------------------------

        # GET|POST /search/* — Feratel availability / additional-service search.
        def search(base, summary)
          get_post(base, summary, [es_id], Common.envelope_response(t('paths.external_sources.search_response')), tags: TAGS_FERATEL)
        end

        # GET|POST /facets/locations/{type} — Feratel location facets.
        def facets_locations
          params = [es_id, Common.string_path_param('type', t('paths.external_sources.facets_type'), example: 'accommodations')]
          get_post('FacetsLocations', t('paths.external_sources.facets_summary'), params, Common.json_object_response(t('paths.external_sources.facets_response'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.facet_collection), tags: TAGS_FERATEL)
        end

        # GET+POST builder (POST mirrors the query via the ContentQuery body).
        def get_post(base, summary, parameters, ok_response, tags: TAGS)
          responses = { '200' => ok_response }.merge(Common.error_responses)
          {
            'get' => Common.operation(operation_id: "get#{base}", summary:, tags:, parameters:, responses:),
            'post' => Common.operation(operation_id: "post#{base}", summary:, tags:, parameters:, responses:, request_body: Common.filter_request_body)
          }
        end

        # ---- shared schemas --------------------------------------------------

        # Flexible import payload: strategy-specific, usually wrapped in @graph.
        def import_body
          {
            'type' => 'object',
            'title' => 'ExternalSourceImport',
            'description' => t('paths.external_sources.import_body'),
            'properties' => {
              '@graph' => { 'type' => 'array', 'items' => { 'type' => 'object', 'additionalProperties' => true } }
            },
            'additionalProperties' => true
          }
        end

        # Timeseries payload: per-attribute [[timestamp, value], …] map or a `data`
        # array; CSV is accepted as text/csv (see ExternalSystemsController#data_from_request).
        def timeseries_body
          {
            'required' => true,
            'content' => {
              'application/json' => {
                'schema' => {
                  'type' => 'object',
                  'title' => 'TimeseriesImport',
                  'description' => t('paths.external_sources.timeseries_body'),
                  'properties' => { 'data' => { 'type' => 'array', 'items' => { 'type' => 'array' } } },
                  'additionalProperties' => { 'type' => 'array', 'items' => { 'type' => 'array' } }
                }
              },
              'text/csv' => { 'schema' => { 'type' => 'string' } }
            }
          }
        end

        # 202 acknowledgement of a timeseries import (Timeseries.create_all):
        # how many rows were inserted vs skipped as duplicates, for which thing.
        def timeseries_import_result
          {
            'type' => 'object',
            'title' => 'TimeseriesImportResult',
            'properties' => {
              'meta' => {
                'type' => 'object',
                'properties' => {
                  'thing_id' => { 'type' => 'string', 'format' => 'uuid' },
                  'processed' => { 'type' => 'object', 'properties' => { 'inserted' => { 'type' => 'integer' }, 'duplicates' => { 'type' => 'integer' } } }
                }
              }
            }
          }
        end

        # Import operations render the strategy result (object or array of results).
        def import_responses
          schema = { 'oneOf' => [{ 'type' => 'object' }, { 'type' => 'array', 'items' => { 'type' => 'object' } }] }
          { '200' => Common.json_response(t('paths.external_sources.import_response'), schema) }.merge(Common.write_error_responses)
        end
      end
    end
  end
end
