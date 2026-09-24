# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Schemas
      module Filters
        # The POST request bodies (DeliveryParams / ContentQuery) and their page
        # / section sub-shapes. Extended into Filters so its methods are
        # available as Filters.* module methods (mirrors Localizable).
        module Body
          # POST body for non-list (single-resource) endpoints that do NOT apply a
          # filter (e.g. /things/{id}); mirrors the delivery query parameters only.
          def delivery_params
            {
              'type' => 'object',
              'title' => 'DeliveryParams',
              'description' => t('filter.delivery_params'),
              'properties' => {
                # canonical order (mirrors the GET query parameters), minus the
                # list-only params (filter/sort/page): shaping → token.
                'fields' => { 'type' => 'string' },
                'include' => { 'type' => 'string' },
                # Only @id and minPrice are permitted (mirrors the dcLiveData query
                # parameter / Api::V4::ContentsController#permitted_parameter_keys).
                'dc:liveData' => { 'type' => 'object', 'properties' => { '@id' => { 'type' => 'string' }, 'minPrice' => { 'type' => 'string' } }, 'additionalProperties' => false },
                'classificationTrees' => { 'type' => 'string' },
                'language' => { 'type' => 'string' },
                'token' => { 'type' => 'string' }
              }
            }
          end

          # The full POST request body (filter + delivery parameters), exposed as
          # the `ContentQuery` component schema.
          def filter_body
            {
              'type' => 'object',
              'title' => 'ContentQuery',
              'description' => t('filter.body'),
              'properties' => {
                # canonical order (mirrors the GET query parameters): what → shaping →
                # paging/envelope → token. Descriptions reuse the query-parameter
                # translations — these body fields map to the same-named params 1:1.
                'filter' => { '$ref' => DataCycleCore::OpenApi::Schemas::Filters::FILTER_REF, 'description' => t('filter.body_filter') },
                'fields' => { 'type' => 'string', 'description' => t('parameters.fields') },
                'include' => { 'type' => 'string', 'description' => t('parameters.include') },
                'classificationTrees' => { 'type' => 'string', 'description' => t('parameters.classification_trees') },
                'language' => { 'type' => 'string', 'description' => t('parameters.language') },
                'sort' => { 'type' => 'string', 'description' => t('parameters.sort') },
                'page' => filter_body_page,
                'section' => filter_body_section,
                'token' => { 'type' => 'string', 'description' => t('parameters.token') }
              }
            }
          end

          # page object of the POST body. Defaults mirror the v4 controller
          # (Api::V4::ApiBaseController::DEFAULT_PAGE_SETTINGS) so they can't drift.
          def filter_body_page
            defaults = DataCycleCore::Api::V4::ApiBaseController::DEFAULT_PAGE_SETTINGS
            {
              'type' => 'object',
              'description' => t('parameters.page'),
              'properties' => {
                'size' => { 'type' => 'integer', 'default' => defaults[:size], 'description' => t('parameters.page_size') },
                'number' => { 'type' => 'integer', 'default' => defaults[:number], 'description' => t('parameters.page_number') },
                'offset' => { 'type' => 'integer', 'default' => defaults[:offset], 'description' => t('parameters.page_offset') },
                'limit' => { 'type' => 'integer', 'default' => defaults[:limit], 'description' => t('parameters.page_limit') }
              }
            }
          end

          # section object of the POST body. Schema and description come from
          # Components::Parameters (the query-parameter side of the same setting) instead
          # of a second copy here: enum, default and the meta-only cost note were written
          # out twice, and a change to one side would have documented two different
          # contracts for one setting. The keys mirror the v4 controller, like the page
          # defaults above.
          def filter_body_section
            params = DataCycleCore::OpenApi::Components::Parameters
            properties = DataCycleCore::Api::V4::ApiBaseController::DEFAULT_SECTION_SETTINGS.keys.to_h do |key|
              [key.to_s, params.section_flag_schema.merge('description' => params.section_flag_description(key.to_s))]
            end

            {
              'type' => 'object',
              'description' => t('parameters.section'),
              'properties' => properties
            }
          end
        end
      end
    end
  end
end
