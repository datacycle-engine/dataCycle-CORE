# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Paths
      # OpenAPI 3.1 paths for the v4 data-delivery endpoints (routes.rb → endpoints/*):
      # content lists/details, suggest, facets, statistics (GET only), timeseries,
      # elevation profile and downloads. Path keys relative to the /api/v4 server base.
      module Delivery
        module_function

        # One tag per operation group, so the delivery endpoints show up as
        # separate sections in the spec/viewer (registered in DocumentBuilder#tags).
        TAGS = ['Delivery'].freeze
        TAGS_SUGGEST = ['Suggest'].freeze
        TAGS_FACETS = ['Facets'].freeze
        TAGS_STATISTICS = ['Statistics'].freeze
        TAGS_TIMESERIES = ['Timeseries'].freeze
        TAGS_ELEVATION = ['Elevation'].freeze
        TAGS_DOWNLOADS = ['Downloads'].freeze

        extend DataCycleCore::OpenApi::Localizable

        # @return [Hash{String=>Hash}] path => path item, for the paths object.
        def all
          {
            '/endpoints/{id}' => endpoint_contents,
            '/endpoints/{id}/{content_id}' => endpoint_content,
            '/endpoints/{id}/suggest' => suggest('suggestEndpoint', t('paths.delivery.suggest_summary')),
            '/endpoints/{id}/suggest_by_title' => suggest('suggestEndpointByTitle', t('paths.delivery.suggest_by_title_summary')),
            # Before the generic facets path on purpose: the route it documents is matched by
            # config/routes.rb ahead of facets/:classification_tree_label_id, and a reader of the
            # document should meet the paths in the order the router resolves them.
            '/endpoints/{id}/facets/externalSystems' => external_system_facets,
            '/endpoints/{id}/facets/{classification_tree_label_id}' => facets,
            '/endpoints/{id}/facets/{classification_tree_label_id}/{classification_id}' => facets_for_classification,
            '/endpoints/{id}/statistics/{attribute}' => statistics,
            '/endpoints/{id}/statistics/{attribute}/{format}' => statistics_format,
            '/endpoints/{id}/{content_id}/{timeseries}' => endpoint_timeseries,
            '/endpoints/{id}/{content_id}/{timeseries}/{format}' => endpoint_timeseries_format,
            '/endpoints/{id}/{content_id}/elevation_profile' => elevation_profile,
            '/endpoints/{id}/download' => download_endpoint,
            '/endpoints/{id}/{content_id}/download' => download_thing
          }
        end

        # ---- path parameters -------------------------------------------------

        # `id` path parameter (data endpoint / stored filter id).
        def endpoint_id
          Common.id_path_param('id', t('paths.delivery.endpoint_id'))
        end

        # `content_id` path parameter.
        def content_id
          Common.id_path_param('content_id', t('paths.delivery.content_id'))
        end

        # ---- content lists & details ----------------------------------------

        # GET/POST /endpoints/{id} — contents of a data endpoint (list, filterable).
        def endpoint_contents
          list_item('getEndpointContents', t('paths.delivery.contents_summary'), [endpoint_id])
        end

        # GET/POST /endpoints/{id}/{content_id} — one content within an endpoint.
        def endpoint_content
          single_item('getEndpointContent', t('paths.delivery.content_summary'), [endpoint_id, content_id])
        end

        # ---- suggest / facets ------------------------------------------------

        # GET/POST /endpoints/{id}/suggest(_by_title) — typeahead.
        def suggest(base, summary)
          params = [endpoint_id] + Common.list_parameters + suggest_parameters
          responses = { '200' => Common.envelope_response(t('paths.delivery.suggestions_response')) }.merge(Common.error_responses)
          get_post(base, summary, params, responses, body: Common.filter_request_body, tags: TAGS_SUGGEST)
        end

        # `search`/`limit` query parameters for the suggest (typeahead) operations
        # -- real Api::V4::ContentsController#permitted_parameter_keys parameters
        # that Common.list_parameters does not cover.
        def suggest_parameters
          [
            DataCycleCore::OpenApi::Components::Parameters.query_string('search', t('paths.delivery.suggest_search')),
            DataCycleCore::OpenApi::Components::Parameters.query_integer('limit', t('paths.delivery.suggest_limit'), default: 10, minimum: 1)
          ]
        end

        # GET/POST /endpoints/{id}/facets/externalSystems — one entry per external system the
        # endpoint's contents were imported from. minCount is a real parameter of this action
        # (ExternalSystemsController#facets reads min_count/minCount), unlike the classification
        # facets, whose thresholds are the min_count_with/without_subtree pair.
        def external_system_facets
          params = [endpoint_id] + Common.list_parameters + [
            DataCycleCore::OpenApi::Components::Parameters.query_integer('minCount', t('paths.delivery.external_system_facets_min_count'), minimum: 0)
          ]
          responses = { '200' => Common.json_object_response(t('paths.delivery.external_system_facets_response'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.external_system_facet_collection) }.merge(Common.error_responses)
          get_post('getEndpointExternalSystemFacets', t('paths.delivery.external_system_facets_summary'), params, responses, body: Common.filter_request_body, tags: TAGS_FACETS)
        end

        # GET/POST /endpoints/{id}/facets/{classification_tree_label_id} — facet counts.
        def facets
          params = [endpoint_id, Common.id_path_param('classification_tree_label_id', t('paths.delivery.facets_tree_label_id'))] + Common.list_parameters
          responses = { '200' => Common.json_object_response(t('paths.delivery.facets_response'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.facet_collection) }.merge(Common.error_responses)
          get_post('getEndpointFacets', t('paths.delivery.facets_summary'), params, responses, body: Common.filter_request_body, tags: TAGS_FACETS)
        end

        # GET/POST /endpoints/{id}/facets/{classification_tree_label_id}/{classification_id}.
        def facets_for_classification
          params = [endpoint_id, Common.id_path_param('classification_tree_label_id', t('paths.delivery.facets_tree_label_id_plain')), Common.id_path_param('classification_id', t('paths.delivery.facets_classification_id'))] + Common.list_parameters
          responses = { '200' => Common.json_object_response(t('paths.delivery.facets_for_classification_response'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.facet_collection) }.merge(Common.error_responses)
          get_post('getEndpointFacetsForClassification', t('paths.delivery.facets_for_classification_summary'), params, responses, body: Common.filter_request_body, tags: TAGS_FACETS)
        end

        # ---- statistics (GET only) ------------------------------------------

        # GET /endpoints/{id}/statistics/{attribute} — aggregated statistics.
        def statistics
          params = [endpoint_id, Common.string_path_param('attribute', t('paths.delivery.statistics_attribute'))] + Common.list_parameters + statistics_parameters
          responses = { '200' => Common.json_object_response(t('paths.delivery.statistics_response'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.statistics_data) }.merge(Common.error_responses)
          { 'get' => Common.operation(operation_id: 'getEndpointStatistics', summary: t('paths.delivery.statistics_summary'), tags: TAGS_STATISTICS, parameters: params, responses:) }
        end

        # GET /endpoints/{id}/statistics/{attribute}/{format} — statistics (json|csv).
        def statistics_format
          params = [endpoint_id, Common.string_path_param('attribute', t('paths.delivery.statistics_attribute')), Common.parameter_ref('format')] + Common.list_parameters + statistics_parameters
          responses = { '200' => Common.json_csv_response(t('paths.delivery.statistics_response_json_csv'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.statistics_data) }.merge(Common.error_responses)
          { 'get' => Common.operation(operation_id: 'getEndpointStatisticsWithFormat', summary: t('paths.delivery.statistics_format_summary'), tags: TAGS_STATISTICS, parameters: params, responses:) }
        end

        # `groupBy`/`time` query parameters for the statistics operations -- real
        # ContentsController#statistics_params parameters not covered by
        # Common.list_parameters.
        def statistics_parameters
          [
            Common.group_by_parameter(t('paths.delivery.statistics_group_by'), enum: DataCycleCore::ApiRenderer::StatisticsRenderer::DEFAULT_GROUPS),
            Common.time_parameter(t('paths.delivery.statistics_time'))
          ]
        end

        # ---- timeseries -----------------------------------------------------

        # GET/POST /endpoints/{id}/{content_id}/{timeseries}.
        def endpoint_timeseries
          params = timeseries_params
          responses = { '200' => Common.json_object_response(t('paths.common.timeseries_data'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.timeseries_data) }.merge(Common.error_responses)
          get_post('getEndpointTimeseries', t('paths.delivery.timeseries_summary'), params, responses, body: Common.delivery_request_body, tags: TAGS_TIMESERIES)
        end

        # GET/POST /endpoints/{id}/{content_id}/{timeseries}/{format}.
        def endpoint_timeseries_format
          params = timeseries_params + [Common.parameter_ref('format')]
          responses = { '200' => Common.json_csv_response(t('paths.common.timeseries_data_json_csv'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.timeseries_data) }.merge(Common.error_responses)
          get_post('getEndpointTimeseriesWithFormat', t('paths.delivery.timeseries_format_summary'), params, responses, body: Common.delivery_request_body, tags: TAGS_TIMESERIES)
        end

        # Path/query params for the endpoint-scoped timeseries operations.
        def timeseries_params
          [endpoint_id, content_id, Common.string_path_param('timeseries', t('paths.delivery.timeseries_name'), example: 'measuredValue')] + Common.delivery_parameters + Common.timeseries_query_parameters
        end

        # ---- elevation ------------------------------------------------------

        # GET/POST /endpoints/{id}/{content_id}/elevation_profile.
        def elevation_profile
          params = [endpoint_id, content_id] + Common.delivery_parameters
          responses = { '200' => Common.json_object_response(t('paths.delivery.elevation_response'), schema: DataCycleCore::OpenApi::Schemas::ResponseBodies.elevation_profile) }.merge(Common.error_responses)
          get_post('getElevationProfile', t('paths.delivery.elevation_summary'), params, responses, body: Common.delivery_request_body, tags: TAGS_ELEVATION)
        end

        # ---- downloads -------------------------------------------------------

        # GET/POST /endpoints/{id}/download — whole collection as a file.
        def download_endpoint
          params = [endpoint_id] + Common.list_parameters
          responses = { '200' => Common.file_response(t('paths.delivery.download_endpoint_response')) }.merge(Common.error_responses)
          get_post('downloadEndpoint', t('paths.delivery.download_endpoint_summary'), params, responses, body: Common.filter_request_body, tags: TAGS_DOWNLOADS)
        end

        # GET/POST /endpoints/{id}/{content_id}/download — single content as a file.
        def download_thing
          params = [endpoint_id, content_id] + Common.delivery_parameters
          responses = { '200' => Common.file_response(t('paths.delivery.download_thing_response')) }.merge(Common.error_responses)
          get_post('downloadThing', t('paths.delivery.download_thing_summary'), params, responses, body: Common.delivery_request_body, tags: TAGS_DOWNLOADS)
        end

        # ---- builders --------------------------------------------------------

        # A filterable list path item (POST carries the ContentQuery).
        def list_item(base, summary, path_params)
          responses = { '200' => Common.envelope_response(t('paths.common.contents_list')) }.merge(Common.error_responses)
          {
            'get' => Common.operation(operation_id: base, summary:, tags: TAGS, parameters: path_params + Common.list_parameters, responses:),
            'post' => Common.operation(operation_id: "#{base}ViaPost", summary: "#{summary}#{t('paths.common.via_post_suffix')}", tags: TAGS, parameters: path_params + Common.list_parameters(with_filter: false), responses:, request_body: Common.filter_request_body)
          }
        end

        # A single-resource path item (POST carries the DeliveryParams body).
        def single_item(base, summary, path_params)
          responses = { '200' => Common.envelope_response(t('paths.common.single_content')) }.merge(Common.error_responses)
          get_post(base, summary, path_params + Common.delivery_parameters, responses, body: Common.delivery_request_body)
        end

        # Generic GET+POST builder with an explicit POST request body.
        def get_post(base, summary, parameters, responses, body:, tags: TAGS)
          {
            'get' => Common.operation(operation_id: base, summary:, tags:, parameters:, responses:),
            'post' => Common.operation(operation_id: "#{base}ViaPost", summary: "#{summary}#{t('paths.common.via_post_suffix')}", tags:, parameters:, responses:, request_body: body)
          }
        end
      end
    end
  end
end
