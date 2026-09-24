# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    # Assembles the per-instance OpenAPI 3.1 document (frame + components + paths).
    class DocumentBuilder
      # Whitelist of the exact paths that may appear in the generated document. A
      # path is emitted only when its template is listed here verbatim (including
      # the {param} placeholders). To hide a single endpoint, remove or comment out
      # its line — its siblings are unaffected because each path stands on its own.
      #
      # Both the Swagger viewer and the JSON controller render this same document
      # (and #tags is pruned to the groups still referenced), so both follow this
      # list automatically. Feature-gated paths (e.g. '/text' for Translate) are harmless
      # when listed: they only reach the filter when the feature is on.
      #
      # Hidden paths are commented out in place rather than deleted, so the source still
      # names them and document_builder_test can tell "hidden on purpose" from "forgotten".
      # Most carry their reason on the line; the Config group gets its reason here instead,
      # because alphabetical order puts '/common' nowhere near the '/feature' and
      # '/schema(/{template_name})' it belongs with. Those four describe the instance's own
      # configuration rather than its data and are system_admin-only (roles/system_admin.yml),
      # so an API consumer reading this document can neither call them nor use them.
      # '/openapi' stays listed, so the document still names where it is served from.
      PATH_ALLOWLIST = [
        '/auth/check_credentials',
        '/auth/login',
        '/auth/logout',
        '/auth/renew_login',
        '/collections',
        '/collections/create',
        '/collections/{id}',
        '/collections/{id}/add_item',
        '/collections/{id}/add_item/{thing_id}',
        '/collections/{id}/download_and_reset',
        '/collections/{id}/remove_item',
        '/collections/{id}/remove_item/{thing_id}',
        # '/common', # hidden: Config group
        '/concept_schemes',
        '/concept_schemes/{id}',
        '/concept_schemes/{id}/concepts',
        '/concept_schemes/{id}/concepts/{classification_id}',
        '/endpoints',
        '/endpoints/{id}',
        '/endpoints/{id}/{content_id}',
        '/endpoints/{id}/{content_id}/download',
        '/endpoints/{id}/{content_id}/elevation_profile',
        '/endpoints/{id}/{content_id}/{timeseries}',
        # '/endpoints/{id}/{content_id}/{timeseries}/{format}', # hidden: remove the leading '# ' to expose again
        '/endpoints/{id}/download',
        '/endpoints/{id}/facets/externalSystems',
        '/endpoints/{id}/facets/{classification_tree_label_id}',
        '/endpoints/{id}/facets/{classification_tree_label_id}/{classification_id}',
        '/endpoints/{id}/statistics/{attribute}',
        '/endpoints/{id}/statistics/{attribute}/{format}',
        '/endpoints/{id}/suggest',
        '/endpoints/{id}/suggest_by_title',
        # '/endpoints/{id}/things(/{content_id})' is deliberately absent, not forgotten: it is a
        # deprecated alias of '/endpoints/{id}(/{content_id})' above — config/routes.rb sends both
        # to contents#index — so listing it advertised one endpoint as two. The route itself stays
        # for existing clients, which is why document_builder_test's V4_ROUTE_EXCEPTIONS names it.
        '/external_links',
        '/external_sources/{external_source_id}',
        '/external_sources/{external_source_id}/concepts',
        '/external_sources/{external_source_id}/concepts/{external_key}',
        '/external_sources/{external_source_id}/demote',
        '/external_sources/{external_source_id}/{external_key}',
        '/external_sources/{external_source_id}/{external_key}/{attribute}',
        '/external_sources/{external_source_id}/{external_key}/{attribute}/{format}',
        '/external_sources/{external_source_id}/{external_key}/timeseries',
        '/external_sources/{external_source_id}/{external_key}/timeseries/{attribute}',
        '/external_sources/{external_source_id}/facets/locations/{type}',
        '/external_sources/{external_source_id}/search/additional_service',
        '/external_sources/{external_source_id}/search/availability',
        '/external_sources/{external_source_id}/things/select',
        '/external_sources/{external_source_id}/things/select/{external_keys}',
        '/external_systems/{external_system_id}/things',
        '/external_systems/{external_system_id}/things/{ids}',
        # '/feature', # hidden: Config group
        '/openapi',
        # '/schema', # hidden: Config group
        # '/schema/{template_name}', # hidden: Config group
        '/text',
        '/things/deleted',
        '/things/{id}/duplicates',
        '/things/{id}/duplicates/{duplicate_id}/false_positive',
        '/things/{id}/duplicates/{duplicate_id}/merge',
        '/things/{id}/external_connections',
        '/things/{id}/external_connections/demote',
        '/things/{id}/external_connections/promote',
        '/things/{id}/{timeseries}',
        '/things/{id}/{timeseries}/{format}',
        '/things/select',
        '/things/select/{uuids}',
        '/universal/{id}',
        '/users',
        '/users/confirm',
        '/users/create',
        '/users/{id}',
        '/users/password',
        '/users/resend_confirmation',
        '/users/update'
      ].to_set.freeze

      # The Paths::* modules whose #all output is merged into the document, in
      # display order. Single source of truth for "which path modules exist" —
      # #paths iterates it and the test suite reuses it, so a new module can't be
      # wired into the document while the completeness guards silently drift.
      # Translate is intentionally NOT listed here: it is feature-gated and appended
      # separately in #paths (see #translate_enabled?).
      PATH_MODULES = [
        :Contents, :Delivery, :Duplicates, :ExternalConnections, :Endpoints, :Classifications, :Collections, :DataLinks, :Users, :ExternalSources, :ExternalSystemsExport, :Authentication, :Config
      ].freeze

      # The cache key of ONE document. Public and a class method because two sides need it:
      # #call writes under it, and the template import deletes under it
      # (MasterData::Templates::TemplateImporter#invalidate_open_api_document_cache).
      #
      # Spelled out twice, the two drifted apart SILENTLY: the key gained a segment when the
      # allowlist fingerprint was added, while the invalidation kept deleting the old name and
      # so hit nothing. A template import then had no effect for up to an hour — neither in
      # the document nor in anything derived from it (the viewer, /api/config/schema). A cache
      # miss is cheap; a silently stale schema is not.
      #
      # The key carries everything that changes the output: the locale, the path allowlist (a
      # code constant, but Rails.cache outlives a deployment) and whether the Translate feature
      # is enabled, which decides whether /text appears in the document.
      #
      # @param locale [Symbol, String] the locale the document is built in
      # @return [String] the cache key for that locale's document
      def self.cache_key(locale)
        fingerprint = Digest::SHA1.hexdigest([PATH_ALLOWLIST.sort.join(','), translate_enabled?].join('|'))

        "data_cycle_core/open_api/document_builder/#{locale}/#{fingerprint}"
      end

      # The translate endpoint is only routed when the Translate feature is
      # enabled (config/routes.rb), so it is documented only then.
      def self.translate_enabled?
        DataCycleCore::Feature['Translate']&.enabled?.present?
      end

      # @param locale [Symbol, String] locale used for localized titles/descriptions
      def initialize(locale: I18n.default_locale)
        @locale = resolved_locale(locale)
      end

      # Builds the full OpenAPI 3.1 document as a Hash. Every builder resolves its
      # texts via I18n, so the whole assembly runs with the requested locale set.
      #
      # Rebuilding all ~89 component schemas from scratch measured at 90-240ms per
      # call -- cheap enough for a human occasionally loading /api/config/openapi
      # or /schema, expensive for anything that would rebuild it per request.
      # TemplateImporter#invalidate_open_api_document_cache clears this on template changes.
      def call
        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          I18n.with_locale(@locale) do
            built_paths = paths
            {
              'openapi' => '3.1.0',
              'info' => info,
              'servers' => [{ 'url' => '/api/v4' }],
              'security' => DataCycleCore::OpenApi::Components::SecuritySchemes.global_security,
              'tags' => tags(built_paths),
              'paths' => built_paths,
              'components' => components
            }
          end
        end
      end

      private

      # @see .cache_key — one spelling for both writing and invalidating.
      def cache_key
        self.class.cache_key(@locale)
      end

      # Guards the given locale, falling back to the default when it is blank or
      # not configured. Requested-language normalization (comma/array handling,
      # user fallback) is owned by the controller layer (AvailableLocaleResolver),
      # which resolves ?language= to a single valid locale before it reaches here;
      # this only coerces and defends the default constructor value.
      def resolved_locale(locale)
        candidate = locale.to_s.presence&.to_sym
        I18n.available_locales.include?(candidate) ? candidate : I18n.default_locale
      end

      # OpenAPI info object. `title`/`version` are stable identifiers (not translated).
      def info
        {
          'title' => 'dataCycle API v4',
          'description' => DataCycleCore::OpenApi::Translations.t('info.description'),
          'version' => '4'
        }
      end

      # Global tag definitions referenced by the path operations (order = display
      # order in viewers). Delivery is split into its operation groups: the core
      # content delivery plus Suggest, Facets, Statistics, Timeseries (shared with
      # the thing-scoped timeseries from Contents) and Downloads. Tag objects have
      # no native hierarchy in OpenAPI, so the grouping is expressed through the
      # 'x-parent' vendor extension (rendered as sub-items by the dataCycle viewer).
      #
      # Pruned to the groups still referenced by the (allowlist-filtered) paths, so
      # trimming PATH_ALLOWLIST never leaves an empty group in the viewer.
      def tags(paths)
        list = [
          { 'name' => 'Contents' },
          { 'name' => 'Duplicates', 'x-parent' => 'Contents' },
          { 'name' => 'External Connections', 'x-parent' => 'Contents' },
          { 'name' => 'Delivery' },
          { 'name' => 'Suggest', 'x-parent' => 'Delivery' },
          { 'name' => 'Facets', 'x-parent' => 'Delivery' },
          { 'name' => 'Statistics', 'x-parent' => 'Delivery' },
          { 'name' => 'Timeseries', 'x-parent' => 'Delivery' },
          { 'name' => 'Elevation', 'x-parent' => 'Delivery' },
          { 'name' => 'Downloads', 'x-parent' => 'Delivery' },
          { 'name' => 'Classifications' },
          { 'name' => 'Collections' },
          { 'name' => 'Endpoints' },
          { 'name' => 'External Links' },
          { 'name' => 'Users' },
          { 'name' => 'External Sources' },
          { 'name' => 'Timeseries Import', 'x-parent' => 'External Sources' },
          { 'name' => 'External Lookup', 'x-parent' => 'External Sources' },
          { 'name' => 'Feratel', 'x-parent' => 'External Sources' },
          { 'name' => 'Export', 'x-parent' => 'External Sources' },
          { 'name' => 'Authentication' },
          { 'name' => 'Config' }
        ]
        list << { 'name' => 'Translate' } if translate_enabled?
        prune_tags(list, paths)
      end

      # Keeps only the tags referenced by an operation in the given paths, plus the
      # x-parent groups of any kept tag so the viewer hierarchy stays intact.
      def prune_tags(list, paths)
        used = tags_used_by(paths)
        parents = list.filter_map { |tag| tag['x-parent'] if used.include?(tag['name']) }.to_set
        list.select { |tag| used.include?(tag['name']) || parents.include?(tag['name']) }
      end

      # Names of every tag attached to an operation across all path items.
      def tags_used_by(paths)
        paths.each_value.with_object(Set.new) do |item, acc|
          item.each_value do |operation|
            acc.merge(operation['tags']) if operation.is_a?(Hash) && operation['tags'].is_a?(Array)
          end
        end
      end

      # All documented paths of the v4 API (read + write/management) plus the
      # config and (feature-gated) translate endpoints. POST operations get their
      # query parameters stripped (see strip_post_query_parameters): on POST the
      # same inputs are carried by the requestBody (ContentQuery / DeliveryParams),
      # so repeating them as query parameters would be redundant.
      def paths
        merged = PATH_MODULES.each_with_object({}) { |mod, acc| acc.merge!(Paths.const_get(mod).all) }
        merged.merge!(DataCycleCore::OpenApi::Paths::Translate.all) if translate_enabled?

        strip_post_query_parameters(filter_allowed_paths(merged))
      end

      # Restricts the merged paths to those whose key is listed in PATH_ALLOWLIST.
      def filter_allowed_paths(paths)
        paths.select { |path, _item| path_allowed?(path) }
      end

      # True when the exact path template is listed in PATH_ALLOWLIST.
      def path_allowed?(path)
        PATH_ALLOWLIST.include?(path)
      end

      # @see .translate_enabled? — part of the cache key too, hence on the class.
      def translate_enabled?
        self.class.translate_enabled?
      end

      # Removes every `in: query` parameter from all POST operations, keeping
      # path parameters (inline or referenced). $ref parameters are resolved
      # against the document's own parameter components to read their `in`, so
      # no parameter names are hardcoded here.
      def strip_post_query_parameters(paths)
        components = parameters

        paths.each_value do |item|
          post = item['post']
          next unless post.is_a?(Hash) && post['parameters'].is_a?(Array)

          post['parameters'] = post['parameters'].reject { |param| query_parameter?(param, components) }
        end

        paths
      end

      # True when a parameter object (inline or $ref) resolves to `in: query`.
      def query_parameter?(param, components)
        return false unless param.is_a?(Hash)

        resolved = param['$ref'] ? components[param['$ref'].to_s.split('/').last] : param
        resolved.is_a?(Hash) && resolved['in'] == 'query'
      end

      # OpenAPI components object.
      def components
        {
          'schemas' => schemas,
          'parameters' => parameters,
          'responses' => DataCycleCore::OpenApi::Components::Responses.all,
          'securitySchemes' => DataCycleCore::OpenApi::Components::SecuritySchemes.all
        }
      end

      # Component schemas: shared building blocks + envelope/filter schemas, one
      # entity schema per ThingTemplate of the instance, plus the AnyEntity union
      # of the instance's top-level entity types (browsable in the Schemas list).
      def schemas
        base = DataCycleCore::OpenApi::Schemas::SharedComponents.all
        base.merge!(DataCycleCore::OpenApi::Components::Responses.schemas)
        base.merge!(DataCycleCore::OpenApi::Schemas::Filters.schemas)

        # Reserved keys: the curated shared/envelope/filter blocks already merged
        # above, plus AnyEntity added below. A ThingTemplate may be named like a
        # schema.org type (e.g. the embedded `PropertyValue` from schema-base), and
        # its generated key would otherwise overwrite the curated block that
        # additionalProperty/identifier/Concept $ref — silently documenting the
        # wrong shape. Skip those templates so the curated block always wins.
        reserved = base.keys.to_set << 'AnyEntity'

        # AnyEntity is the union of the entity types that can appear at the top
        # level of a content @graph, so its union is built from the non-embedded
        # templates only. Component schemas are still generated for ALL templates
        # (embedded ones stay referenceable via their own $ref).
        top_level_names = DataCycleCore::ThingTemplate.without_embedded.pluck(:template_name).to_set

        entity_names = []
        DataCycleCore::ThingTemplate.all.each_with_object(base) do |template, acc|
          key = DataCycleCore::OpenApi::EntityBuilder.component_name(template.template_name)
          next if reserved.include?(key)

          acc[key] = DataCycleCore::OpenApi::EntityBuilder.new(template, locale: @locale).call
          entity_names << key if top_level_names.include?(template.template_name)
        end

        base['AnyEntity'] = any_entity(entity_names)
        base
      end

      # Union of the top-level entity schemas (the entity types a content @graph
      # can contain); listed in the Schemas section for reference.
      def any_entity(entity_names)
        {
          'title' => 'AnyEntity',
          'description' => DataCycleCore::OpenApi::Translations.t('schemas.any_entity'),
          'oneOf' => entity_names.uniq.sort.map { |n| { '$ref' => "#/components/schemas/#{n}" } }
        }
      end

      # Shared query parameters plus the deepObject filter parameter. Built once
      # per instance: it is consumed both by #components and by the POST query
      # stripping (#strip_post_query_parameters), and each build runs the t()
      # interpolations. Safe to memoize — the whole assembly runs under a single
      # ambient locale (I18n.with_locale(@locale) in #call).
      def parameters
        @parameters ||= begin
          base = DataCycleCore::OpenApi::Components::Parameters.all
          base.merge(DataCycleCore::OpenApi::Schemas::Filters.parameters)
        end
      end
    end
  end
end
