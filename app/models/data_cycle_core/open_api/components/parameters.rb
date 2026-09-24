# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Components
      # Shared OpenAPI 3.1 components/parameters for the v4 read API.
      #
      # Names and semantics taken from the v4 base controller
      # (Api::V4::ApiBaseController#permitted_parameter_keys, DEFAULT_PAGE_SETTINGS,
      # DEFAULT_SECTION_SETTINGS). Paging and section use bracket notation
      # (page[size], section[@graph]) as consumed by the controller.
      module Parameters
        module_function

        extend DataCycleCore::OpenApi::Localizable

        # Documented paging/section defaults mirror the v4 controller so they can
        # never drift from the values the API actually applies.
        def page_defaults
          DataCycleCore::Api::V4::ApiBaseController::DEFAULT_PAGE_SETTINGS
        end

        # Documented default for a section flag (all sections share the same default).
        def section_default
          DataCycleCore::Api::V4::ApiBaseController::DEFAULT_SECTION_SETTINGS.values.first
        end

        # @return [Hash{String=>Hash}] component name => OpenAPI parameter object,
        #   ready to be merged into components/parameters.
        # Canonical parameter order — kept consistent everywhere the same params
        # appear (GET query params, ContentQuery/DeliveryParams bodies): what/which
        # content → how it is shaped → paging/envelope → technical (token/format).
        def all
          {
            'fields' => fields,
            'include' => include_param,
            'dcLiveData' => dc_live_data,
            'classificationTrees' => classification_trees,
            'language' => language,
            'sort' => sort,
            'pageSize' => page_size,
            'pageNumber' => page_number,
            'pageOffset' => page_offset,
            'pageLimit' => page_limit,
            'sectionGraph' => section_flag('@graph'),
            'sectionContext' => section_flag('@context'),
            'sectionMeta' => section_flag('meta'),
            'sectionLinks' => section_flag('links'),
            'token' => token,
            'format' => format,
            'api_subversion' => api_subversion,
            'external_source_id' => external_source_id,
            'external_key' => external_key,
            'attribute' => attribute
          }
        end

        # Build a reusable query parameter backed by a string schema. `required:` exists
        # for the few query parameters that really are mandatory (Paths::Translate's
        # `text`), which previously kept their own copy of this builder next to this one.
        def query_string(name, description, required: false, **schema_opts)
          {
            'name' => name,
            'in' => 'query',
            'required' => required,
            'description' => description,
            'schema' => { 'type' => 'string', **schema_opts.transform_keys(&:to_s) }
          }
        end

        # `token` — API access token as a query parameter.
        def token
          query_string('token', t('parameters.token'))
        end

        # `fields` — attribute tree restricting the returned attributes.
        def fields
          query_string('fields', t('parameters.fields'))
        end

        # `include` — attribute tree expanding linked/embedded entities.
        def include_param
          query_string('include', t('parameters.include'))
        end

        # `language` — requested content locale(s). The example is taken from the
        # instance's configured locales instead of a hardcoded code.
        def language
          query_string('language', t('parameters.language'), example: I18n.default_locale.to_s)
        end

        # `sort` — comma-separated sort keys (`-` prefix = descending).
        def sort
          query_string('sort', t('parameters.sort'))
        end

        # `classificationTrees` — restrict dc:classification to given trees.
        def classification_trees
          query_string('classificationTrees', t('parameters.classification_trees'))
        end

        # `dc:liveData` — request live/computed values for specific attributes.
        def dc_live_data
          {
            'name' => 'dc:liveData',
            'in' => 'query',
            'required' => false,
            'description' => t('parameters.live_data'),
            'style' => 'deepObject',
            'explode' => true,
            # Only @id and minPrice are permitted (Api::V4::ContentsController
            # #permitted_parameter_keys: 'dc:liveData': [:@id, :minPrice]); any
            # other key is dropped by strong parameters.
            'schema' => {
              'type' => 'object',
              'properties' => {
                '@id' => { 'type' => 'string' },
                'minPrice' => { 'type' => 'string' }
              },
              'additionalProperties' => false
            }
          }
        end

        # `format` — explicit output-format path segment (json | csv).
        def format
          {
            'name' => 'format',
            'in' => 'path',
            'required' => true,
            'description' => t('parameters.format'),
            'schema' => { 'type' => 'string', 'enum' => ['json', 'csv'], 'default' => 'json' }
          }
        end

        # Build a reusable required string path parameter.
        def path_string(name, description, **schema_opts)
          {
            'name' => name,
            'in' => 'path',
            'required' => true,
            'description' => description,
            'schema' => { 'type' => 'string', **schema_opts.transform_keys(&:to_s) }
          }
        end

        # `api_subversion` — optional route-prefix segment (config/routes.rb →
        # `scope path: '(/:api_subversion)'`). Every v4 path may be prefixed with a
        # sub-version segment. The prefix is normally absorbed by the `/api/v4`
        # server base (see Paths::Common), so this component is provided for
        # reference/tooling and is not templated into the individual path keys.
        def api_subversion
          path_string('api_subversion', t('parameters.api_subversion'))
        end

        # `external_source_id` — id or identifier of the external system
        # (constraints: %r{[^/]+}; matched by ExternalSystem#identifier or #id).
        def external_source_id
          path_string('external_source_id', t('parameters.external_source_id'))
        end

        # `external_key` — key of a content within the external system.
        def external_key
          path_string('external_key', t('parameters.external_key'))
        end

        # `attribute` — api_name of a (timeseries) attribute addressed in the path.
        def attribute
          path_string('attribute', t('parameters.attribute'))
        end

        # Build a reusable query parameter backed by an integer schema.
        def query_integer(name, description, default: nil, minimum: nil)
          schema = { 'type' => 'integer' }
          schema['minimum'] = minimum unless minimum.nil?
          schema['default'] = default unless default.nil?
          {
            'name' => name,
            'in' => 'query',
            'required' => false,
            'description' => description,
            'schema' => schema
          }
        end

        # `page[size]` — items per page.
        def page_size
          query_integer('page[size]', t('parameters.page_size'), default: page_defaults[:size], minimum: 1)
        end

        # `page[number]` — 1-based page number.
        def page_number
          query_integer('page[number]', t('parameters.page_number'), default: page_defaults[:number], minimum: 1)
        end

        # `page[offset]` — additional item offset.
        def page_offset
          query_integer('page[offset]', t('parameters.page_offset'), default: page_defaults[:offset], minimum: 0)
        end

        # `page[limit]` — hard item limit (overrides size/number when positive).
        def page_limit
          query_integer('page[limit]', t('parameters.page_limit'), default: page_defaults[:limit], minimum: 0)
        end

        # section[<key>]=0|1 toggles the top-level envelope sections
        # (@graph, @context, meta, links); all default to 1.
        # Note: `section[meta]=0` also skips the (expensive) total count query.
        def section_flag(key)
          {
            'name' => "section[#{key}]",
            'in' => 'query',
            'required' => false,
            'description' => section_flag_description(key),
            'schema' => section_flag_schema
          }
        end

        # Schema and description of ONE section flag, shared with the POST body
        # (Schemas::Filters::Body#filter_body_section describes the same flags as
        # object properties instead of query parameters). Both sides carried their
        # own copy of the enum, the default and the meta-only cost note -- a change
        # to either would have documented two different contracts for one setting.
        def section_flag_schema
          { 'type' => 'integer', 'enum' => [0, 1], 'default' => section_default }
        end

        # `meta` carries an extra note: switching it off also skips the total count query.
        def section_flag_description(key)
          t('parameters.section_flag', key:, extra: key == 'meta' ? t('parameters.section_flag_meta_extra') : '')
        end
      end
    end
  end
end
