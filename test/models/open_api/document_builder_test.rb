# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module OpenApi
    # Tests the locale normalization of DocumentBuilder and that the assembled
    # document is rendered with the requested locale (builders resolve their
    # texts through the ambient I18n locale set by #call).
    class DocumentBuilderTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def resolve(locale)
        DocumentBuilder.new(locale:).send(:resolved_locale, locale)
      end

      test 'resolved_locale keeps an available locale' do
        assert_equal :de, resolve(:de)
        assert_equal :en, resolve('en')
      end

      # Requested-language normalization (comma lists, arrays, user fallback) is
      # owned by the controller layer (AvailableLocaleResolver), which hands the
      # builder a single already-resolved locale. The builder no longer splits
      # comma lists itself; an unresolvable value falls back to the default.
      test 'resolved_locale does not normalize a comma separated list; it falls back to the default' do
        assert_equal I18n.default_locale, resolve('de,en')
        assert_equal I18n.default_locale, resolve('en,de')
      end

      test 'resolved_locale falls back to the default locale for unknown, nil or blank input' do
        assert_equal I18n.default_locale, resolve('xx')
        assert_equal I18n.default_locale, resolve(nil)
        assert_equal I18n.default_locale, resolve('')
        assert_equal I18n.default_locale, resolve('   ')
      end

      test 'defaults to the default locale when constructed without an argument' do
        assert_equal I18n.default_locale, DocumentBuilder.new.send(:resolved_locale, I18n.default_locale)
      end

      test 'call returns a valid OpenAPI 3.1 skeleton' do
        document = DocumentBuilder.new(locale: :en).call

        assert_equal '3.1.0', document['openapi']
        assert_equal '4', document.dig('info', 'version')
        assert_equal 'dataCycle API v4', document.dig('info', 'title')
        assert_kind_of Hash, document['paths']
        assert_kind_of Hash, document.dig('components', 'schemas')
      end

      test 'call renders the document with the requested locale regardless of the ambient locale' do
        I18n.with_locale(:en) do
          german = DocumentBuilder.new(locale: :de).call

          assert_equal 'Instanzspezifische OpenAPI-3.1-Beschreibung der dataCycle API v4 (Datenstrukturen, Lese- sowie Schreib-/Verwaltungs-Endpunkte).',
                       german.dig('info', 'description')
          assert_equal 'Die angeforderte Ressource existiert nicht.',
                       german.dig('components', 'responses', 'NotFound', 'description')
        end
      end

      test 'call renders english texts for the english locale' do
        document = DocumentBuilder.new(locale: :en).call

        assert_equal 'Per-instance OpenAPI 3.1 description of the dataCycle API v4 (data structures, read and write/management endpoints).',
                     document.dig('info', 'description')
        assert_equal 'The requested resource does not exist.',
                     document.dig('components', 'responses', 'NotFound', 'description')
      end

      test 'the language parameter example is derived from the instance locales, not hardcoded' do
        document = DocumentBuilder.new(locale: :en).call
        example = document.dig('components', 'parameters', 'language', 'schema', 'example')

        assert_equal I18n.default_locale.to_s, example
        assert_includes I18n.available_locales.map(&:to_s), example
      end

      test 'call leaves the ambient locale unchanged' do
        I18n.with_locale(:en) do
          DocumentBuilder.new(locale: :de).call

          assert_equal :en, I18n.locale
        end
      end

      # Resolves a parameter object (inline or $ref) against the document's own
      # parameter components, returning its `in` value ('query' / 'path' / nil).
      def param_in(document, param)
        resolved = param['$ref'] ? document.dig('components', 'parameters', param['$ref'].split('/').last) : param
        resolved&.fetch('in', nil)
      end

      test 'POST operations expose no query parameters (carried by the request body instead)' do
        document = DocumentBuilder.new(locale: :en).call

        posts = document['paths'].select { |_path, item| item['post'] }

        assert_operator posts.size, :>, 0, 'expected the API to define POST operations'

        posts.each do |path, item|
          query = (item['post']['parameters'] || []).select { |p| param_in(document, p) == 'query' }

          assert_empty query, "POST #{path} must not expose query parameters, found: #{query.map { |p| p['$ref'] || p['name'] }}"
        end
      end

      test 'stripping POST query parameters leaves GET query parameters intact' do
        document = DocumentBuilder.new(locale: :en).call

        get_with_query = document['paths'].any? do |_path, item|
          item['get'] && (item['get']['parameters'] || []).any? { |p| param_in(document, p) == 'query' }
        end

        assert get_with_query, 'expected at least one GET operation to still expose query parameters'
      end

      test 'POST operations keep their path parameters' do
        document = DocumentBuilder.new(locale: :en).call

        thing_ts = document.dig('paths', '/things/{id}/{timeseries}/{format}', 'post')

        assert thing_ts, 'expected the timeseries POST operation to exist'

        path_params = (thing_ts['parameters'] || []).select { |p| param_in(document, p) == 'path' }.map { |p| p['$ref']&.split('/')&.last || p['name'] }

        assert_includes path_params, 'id'
        assert_includes path_params, 'timeseries'
        assert_includes path_params, 'format'
      end

      test 'the single-content /things/{id} endpoint is not exposed, its siblings remain' do
        document = DocumentBuilder.new(locale: :en).call

        assert_not document['paths'].key?('/things/{id}'), '/things/{id} must not be part of the documented API'

        ['/things/{id}/{timeseries}', '/things/{id}/{timeseries}/{format}', '/things/select', '/things/deleted'].each do |path|
          assert document['paths'].key?(path), "expected #{path} to remain documented"
        end
      end

      test 'generated entity schemas never overwrite a curated shared component' do
        # A ThingTemplate may be named like a curated schema.org block (schema-base
        # ships an embedded template literally named PropertyValue). Its generated
        # entity schema must not clobber the curated block that additionalProperty /
        # identifier / Concept $ref — the "$ref resolves" test below cannot catch
        # this because the ref still resolves, just to the wrong (overwritten) shape.
        I18n.with_locale(:en) do
          schemas = DocumentBuilder.new(locale: :en).call.dig('components', 'schemas')

          shared = DataCycleCore::OpenApi::Schemas::SharedComponents.all
          curated = shared
            .merge(DataCycleCore::OpenApi::Components::Responses.schemas)
            .merge(DataCycleCore::OpenApi::Schemas::Filters.schemas)

          curated.each do |name, definition|
            assert_equal definition, schemas[name],
                         "curated shared component #{name} was overwritten by a generated entity schema"
          end
        end
      end

      test 'SharedComponents::NAMES stays in sync with the schemas it actually builds' do
        # NAMES (the authoritative reserved-key list EntityBuilder consults) and the
        # keys of #all (the schemas actually emitted) are two hand-maintained lists.
        # If they drift, a shared block either leaks a generated entity over it or is
        # never reserved — this guard fails the build the moment they diverge.
        assert_equal DataCycleCore::OpenApi::Schemas::SharedComponents.all.keys.sort,
                     DataCycleCore::OpenApi::Schemas::SharedComponents::NAMES.sort
      end

      test 'a template named like a shared component is not added to the AnyEntity union' do
        any_entity = DocumentBuilder.new(locale: :en).call.dig('components', 'schemas', 'AnyEntity')
        referenced = any_entity['oneOf'].map { |o| o['$ref'].split('/').last }
        reserved = DataCycleCore::OpenApi::Schemas::SharedComponents::NAMES

        assert_empty referenced & reserved,
                     "AnyEntity must not reference a curated shared component, found: #{referenced & reserved}"
      end

      test 'every internal $ref resolves within the document' do
        [:de, :en].each do |locale|
          document = DocumentBuilder.new(locale:).call
          refs = []
          collect = lambda do |node|
            case node
            when Hash then node.each { |k, v| k == '$ref' ? refs << v : collect.call(v) }
            when Array then node.each { |v| collect.call(v) }
            end
          end
          collect.call(document)

          dangling = refs.uniq.select do |ref|
            ref.is_a?(String) && ref.start_with?('#/') &&
              ref.delete_prefix('#/').split('/').reduce(document) { |acc, p| acc.is_a?(Hash) ? acc[p] : nil }.nil?
          end

          assert_empty dangling, "[#{locale}] dangling internal $refs: #{dangling}"
        end
      end

      test 'a template whose component_name collides with a curated/reserved key does not overwrite it' do
        builder = DocumentBuilder.new(locale: :en)
        curated = DataCycleCore::OpenApi::Schemas::SharedComponents.all
        reserved_key = curated.keys.first

        assert_not_nil reserved_key, 'expected at least one curated shared component'

        # A template whose generated key equals a reserved one. If the guard were
        # missing, the loop would call EntityBuilder.new(fake).call (raising on this
        # bare stub) or overwrite the curated block; the guard must skip it entirely.
        fake = Struct.new(:template_name).new(reserved_key)

        schemas = DataCycleCore::OpenApi::EntityBuilder.stub(:component_name, ->(name) { name }) do
          DataCycleCore::ThingTemplate.stub(:all, [fake]) do
            DataCycleCore::ThingTemplate.stub(:without_embedded, [fake]) do
              builder.send(:schemas)
            end
          end
        end

        assert_equal curated[reserved_key], schemas[reserved_key],
                     'the curated block must survive a colliding template (not be overwritten)'
        assert_not_includes schemas.dig('AnyEntity', 'oneOf').pluck('$ref'),
                            "#/components/schemas/#{reserved_key}",
                            'a skipped colliding template must not be pulled into the AnyEntity union'
      end

      # Yields [path, http_verb, operation] for every operation object in the
      # document, so the tag assertions below iterate the real operations instead
      # of naming each verb/path by hand. An operation is identified by carrying an
      # operationId (path-level `parameters` arrays and the like are skipped).
      def each_operation(document)
        return enum_for(:each_operation, document) unless block_given?

        document['paths'].each do |path, item|
          item.each { |verb, operation| yield path, verb, operation if operation.is_a?(Hash) && operation.key?('operationId') }
        end
      end

      # The elevation profile was split out of the Timeseries group into its own
      # Delivery sub-group. Expectations are derived from the Paths::Delivery::TAGS_*
      # constants (never the literal names), so renaming a group can't leave a stale
      # assertion; the parent is read off the Timeseries tag entry so "sibling of
      # Timeseries" needs no hardcoded 'Delivery'.
      test 'elevation profile operations form their own Delivery sub-group, split off from Timeseries' do
        document = DocumentBuilder.new(locale: :en).call

        elevation = Paths::Delivery::TAGS_ELEVATION
        timeseries = Paths::Delivery::TAGS_TIMESERIES

        assert_not_equal timeseries, elevation, 'Elevation must be a distinct group from Timeseries'

        elevation_ops = each_operation(document).select { |path, _verb, _op| path.include?('elevation_profile') }

        assert_operator elevation_ops.size, :>, 0, 'expected elevation_profile operations in the document'
        elevation_ops.each do |path, verb, operation|
          assert_equal elevation, operation['tags'], "#{verb.upcase} #{path} must be tagged Elevation, not Timeseries"
        end

        tags_by_name = document['tags'].index_by { |tag| tag['name'] }

        assert_includes tags_by_name.keys, elevation.first, 'Elevation must be registered in the document tags'
        assert_equal tags_by_name.fetch(timeseries.first)['x-parent'], tags_by_name.fetch(elevation.first)['x-parent'],
                     'Elevation must nest under the same parent group as the Timeseries group it left'
      end

      # A tag only renders a sidebar section if it is declared in the document tags,
      # and a sub-group only nests if its x-parent names a declared tag. Fully derived
      # from the document, so it guards this move and any future tag drift (a used but
      # undeclared tag, or an x-parent typo) without naming a single tag.
      test 'every tag used by an operation is declared and every x-parent resolves to a declared tag' do
        document = DocumentBuilder.new(locale: :en).call

        declared = document['tags'].pluck('name').to_set
        used = each_operation(document).flat_map { |_path, _verb, operation| Array(operation['tags']) }.to_set

        assert_empty used - declared, "operations reference undeclared tags: #{(used - declared).to_a}"

        parents = document['tags'].filter_map { |tag| tag['x-parent'] }.to_set

        assert_empty parents - declared, "x-parent references point at undeclared tags: #{(parents - declared).to_a}"
      end

      # ---- path whitelist ------------------------------------------------

      # The whole point of the exact whitelist: the document contains those paths and
      # only those. A non-empty subset proves the filter is wired to PATH_ALLOWLIST —
      # nothing leaks that is not listed, and removing a line really removes the path.
      test 'the documented paths are a non-empty subset of PATH_ALLOWLIST' do
        paths = DocumentBuilder.new(locale: :en).call['paths'].keys.to_set

        assert_operator paths.size, :>, 0, 'expected the document to expose some paths'
        assert paths.subset?(DocumentBuilder::PATH_ALLOWLIST),
               "documented paths not in PATH_ALLOWLIST leaked through the filter: #{(paths - DocumentBuilder::PATH_ALLOWLIST).to_a}"
      end

      # Guards against typos / stale entries: every PATH_ALLOWLIST entry must name a
      # path some Paths::* module actually defines, otherwise a rename silently turns
      # an allowlist line into a dead no-op that no longer whitelists anything.
      test 'PATH_ALLOWLIST references only real, currently defined paths' do
        dead = DocumentBuilder::PATH_ALLOWLIST - merged_defined_paths.keys.to_set

        assert_empty dead, "PATH_ALLOWLIST entries match no defined path (typo or removed endpoint?): #{dead.to_a}"
      end

      # The counter-direction of the test above, and the one that was missing: a path a
      # Paths::* module builds but that nobody listed is dropped SILENTLY -- the operation,
      # its parameters and its response schema are built on every request and then thrown
      # away, and no reader of either file can see it. That is how
      # /endpoints/{id}/facets/externalSystems stayed undocumented although its route,
      # operation and response schema all existed.
      #
      # Deliberately hidden paths stay possible: the documented workflow is to comment the
      # line out, and a commented-out line still names the path in the source. So the guard
      # asks the SOURCE, not the frozen constant -- exactly the difference between "hidden on
      # purpose" and "forgotten".
      test 'every defined path is either allowlisted or explicitly commented out' do
        source = DataCycleCore::Engine.root.join('app/models/data_cycle_core/open_api/document_builder.rb').read
        delisted = source.scan(/^\s*#\s*'([^']+)',/).flatten.to_set

        forgotten = merged_defined_paths.keys.to_set - DocumentBuilder::PATH_ALLOWLIST - delisted

        assert_empty forgotten,
                     "paths are built by a Paths module but neither allowlisted nor commented out -- they are dropped silently: #{forgotten.to_a}"
      end

      # ---- cache key ------------------------------------------------------

      # Writing and invalidating have to hit the same key. They did not: the key gained a segment
      # with the allowlist fingerprint while TemplateImporter#invalidate_open_api_document_cache
      # kept deleting the old name. That fails silently — Rails.cache.delete on a key that does
      # not exist is not an error — and a template import then had no effect for up to an hour,
      # neither in the document nor in the viewer or anything derived from it.
      test 'a template import invalidates exactly the key the builder writes under' do
        locale = I18n.default_locale
        key = DocumentBuilder.cache_key(locale)

        Rails.cache.write(key, { 'openapi' => '3.1.0' })
        DataCycleCore::MasterData::Templates::TemplateImporter.new.send(:invalidate_open_api_document_cache)

        assert_nil Rails.cache.read(key), 'the importer\'s invalidation must hit the key the builder writes under'
      end

      # The key has to carry everything that changes the output — otherwise, after a switch, the
      # cache serves a document that no longer matches the configuration for up to an hour.
      test 'the cache key separates locales and follows the translate feature' do
        assert_not_equal DocumentBuilder.cache_key(:de), DocumentBuilder.cache_key(:en)

        with_translate = DocumentBuilder.stub(:translate_enabled?, true) { DocumentBuilder.cache_key(:de) }
        without = DocumentBuilder.stub(:translate_enabled?, false) { DocumentBuilder.cache_key(:de) }

        assert_not_equal with_translate, without,
                         'das Translate-Feature entscheidet über den /text-Pfad und gehört deshalb in den Schlüssel'
      end

      test 'path_allowed? is an exact match: a listed path matches, an unlisted or partial one does not' do
        builder = DocumentBuilder.new(locale: :en)
        listed = DocumentBuilder::PATH_ALLOWLIST.first

        assert builder.send(:path_allowed?, listed), "#{listed} is listed and must match"
        assert_not builder.send(:path_allowed?, '/definitely/not/listed'), 'an unlisted path must not match'
        assert_not builder.send(:path_allowed?, "#{listed}/extra"), 'a longer path must not match a listed prefix (exact only)'
      end

      test 'filter_allowed_paths keeps only exactly-listed paths' do
        builder = DocumentBuilder.new(locale: :en)
        merged = {
          '/things/select' => { 'get' => {} },      # listed
          '/users/create' => { 'post' => {} },      # listed
          '/things/select/deep/unlisted' => { 'get' => {} }, # not listed (exact match only)
          '/secret' => { 'get' => {} } # not listed
        }

        assert_equal ['/things/select', '/users/create'], builder.send(:filter_allowed_paths, merged).keys
      end

      # The strongest proof that the allowlist actually hides: a path that a Paths::*
      # module really defines, but whose PATH_ALLOWLIST line is commented out, must be
      # absent from the generated document while still counting as defined. Guards the
      # documented "comment out the line to hide an endpoint" workflow end-to-end.
      test 'a defined path that is commented out of PATH_ALLOWLIST is hidden from the document' do
        hidden = '/endpoints/{id}/{content_id}/{timeseries}/{format}'

        assert_includes merged_defined_paths.keys, hidden,
                        'precondition: the path is still defined by a Paths module'
        assert_not_includes DocumentBuilder::PATH_ALLOWLIST, hidden,
                            'precondition: the path is delisted (commented out) in PATH_ALLOWLIST'

        paths = DocumentBuilder.new(locale: :en).call['paths']

        assert_not paths.key?(hidden), 'a delisted-but-defined path must not appear in the document'
      end

      # PATH_MODULES is the single source of truth #paths iterates and the test suite
      # reuses. A typo'd symbol would make const_get raise at build time, but this
      # states the contract explicitly: every entry names a real Paths::* module and
      # Translate is deliberately excluded (it is feature-gated, appended separately).
      test 'PATH_MODULES lists only real Paths modules and excludes the feature-gated Translate' do
        assert_operator DocumentBuilder::PATH_MODULES.size, :>, 0, 'expected some path modules'
        assert_not_includes DocumentBuilder::PATH_MODULES, :Translate,
                            'Translate is feature-gated and must not be in the always-merged module list'

        DocumentBuilder::PATH_MODULES.each do |mod|
          assert Paths.const_defined?(mod), "PATH_MODULES names a non-existent Paths module: #{mod}"
          assert_respond_to Paths.const_get(mod), :all, "Paths::#{mod} must expose .all"
        end
      end

      test 'prune_tags drops groups no operation references and keeps the parent of a kept sub-group' do
        builder = DocumentBuilder.new(locale: :en)
        list = [
          { 'name' => 'Contents' },
          { 'name' => 'Delivery' },
          { 'name' => 'Timeseries', 'x-parent' => 'Delivery' },
          { 'name' => 'Facets', 'x-parent' => 'Delivery' },
          { 'name' => 'Users' }
        ]
        paths = {
          '/things/select' => { 'get' => { 'tags' => ['Contents'] } },
          # a path item also carries non-operation keys (e.g. 'servers'); those must
          # not be mistaken for operations when collecting used tags.
          '/things/{id}/{timeseries}' => { 'get' => { 'tags' => ['Timeseries'] }, 'servers' => [{ 'url' => '/x' }] }
        }

        kept = builder.send(:prune_tags, list, paths).pluck('name')

        assert_equal ['Contents', 'Delivery', 'Timeseries'], kept
      end

      # ---- v4 completeness (#50193) --------------------------------------

      # v4 routes intentionally left undocumented, with a reason. The acceptance
      # criterion allows a route to be "documented OR a justified exception".
      V4_ROUTE_EXCEPTIONS = {
        '/things' => 'index — only routed in Rails.env.local?, not a production endpoint (excluded by #50127)',
        '/things/{id}' => 'single-content show only redirects to the resolved thing; excluded by #50127',
        '/endpoints/{id}/things' => 'deprecated alias: routed to contents#index, the same action as /endpoints/{id}',
        '/endpoints/{id}/things/{content_id}' => 'deprecated alias: routed to contents#index, the same action as /endpoints/{id}/{content_id}',
        '/endpoints/{id}/mcp' => 'MCP protocol endpoint (JSON-RPC over GET/POST/DELETE), not a REST resource describable as an OpenAPI operation'
      }.freeze

      # All paths the Paths::* modules define, before the PATH_ALLOWLIST display
      # filter is applied. "Documented" for the completeness check means an OpenAPI
      # operation exists for the route — a concern independent of whether the path is
      # currently shown, so intentionally whitelisting a path out must not make this
      # guard report the route as undocumented.
      #
      # Reuses DocumentBuilder::PATH_MODULES (the single source of truth #paths also
      # iterates) so this helper can never drift out of sync with the modules the
      # builder actually merges. Translate is appended unconditionally on purpose:
      # its path is feature-gated in the builder but must still count as "defined"
      # here, so the allowlist/completeness guards stay independent of the feature
      # flag's state in the test environment.
      def merged_defined_paths
        (DocumentBuilder::PATH_MODULES + [:Translate])
          .each_with_object({}) { |mod, acc| acc.merge!(Paths.const_get(mod).all) }
      end

      # Every route under the v4 namespace must be described as a path operation
      # or be listed (with a reason) in V4_ROUTE_EXCEPTIONS. Guards against a new
      # v4 route silently missing from the OpenAPI document.
      test 'every v4 route is documented or a justified exception (#50193)' do
        # config/translate path items carry their own server override and are not
        # part of the /api/v4 base, so they are excluded from the v4 route check.
        documented = merged_defined_paths.reject { |_p, item| item.is_a?(Hash) && item.key?('servers') }.keys.to_set

        v4_specs = DataCycleCore::Engine.routes.routes
          .map { |r| r.path.spec.to_s }
          .select { |s| s.start_with?('/api/v4') }
          .uniq

        assert_operator v4_specs.size, :>, 0, 'expected the v4 routes to enumerate'

        undocumented = v4_specs.reject do |spec|
          route_candidates(spec).any? { |candidate| documented.include?(candidate) || V4_ROUTE_EXCEPTIONS.key?(candidate) }
        end

        assert_empty undocumented,
                     "undocumented v4 routes (add a Paths::* operation or a V4_ROUTE_EXCEPTIONS entry): #{undocumented}"
      end

      # config endpoints live under /api/config (a sibling of /api/v4), so their
      # path items must override the server base instead of inheriting /api/v4.
      #
      # Derived from Paths::Config.all rather than a hardcoded list, because all of the
      # group except '/openapi' is hidden from PATH_ALLOWLIST: read off the rendered
      # document this guard would only ever see the one path still displayed, and would
      # go quiet on the four whose override still has to be right the day one is exposed
      # again. '/openapi' is then checked in the document too, as the one that ships.
      test 'config path items are served from /api/config (#50193)' do
        config_paths = Paths::Config.all

        assert_operator config_paths.size, :>, 0, 'expected the config paths to enumerate'

        config_paths.each do |path, item|
          assert_equal '/api/config', item.dig('servers', 0, 'url'), "#{path} must be served from /api/config"
        end

        openapi = DocumentBuilder.new(locale: :en).call.dig('paths', '/openapi')

        assert openapi, 'expected /openapi to stay documented'
        assert_equal '/api/config', openapi.dig('servers', 0, 'url')
      end

      # OpenAPI requires operationId to be unique across the whole document —
      # duplicates make client generators collide. Fully derived, so it guards
      # every current and future operation added by any Paths::* module.
      test 'every operationId is unique across the document (#50193)' do
        document = DocumentBuilder.new(locale: :en).call
        ids = each_operation(document).map { |_path, _verb, operation| operation['operationId'] }
        duplicates = ids.tally.select { |_id, count| count > 1 }

        assert_empty duplicates, "duplicate operationIds: #{duplicates.keys}"
      end

      # The write/management endpoints must be described with their real HTTP
      # methods, not the read-style GET+POST pair (#50193: the correct HTTP method
      # per operation instead of a blanket GET+POST).
      test 'write/management endpoints use their real HTTP methods (#50193)' do
        document = DocumentBuilder.new(locale: :en).call

        {
          '/endpoints' => ['post'],
          '/external_links' => ['post'],
          '/collections/create' => ['post'],
          '/users/create' => ['post'],
          '/users/update' => ['patch', 'put'],
          '/users/confirm' => ['patch', 'put'],
          '/external_sources/{external_source_id}' => ['post', 'put', 'patch', 'delete'],
          '/external_sources/{external_source_id}/{external_key}' => ['put', 'patch', 'delete']
        }.each do |path, verbs|
          item = document['paths'][path]

          assert item, "expected #{path} to be documented"
          verbs.each { |verb| assert item.key?(verb), "#{path} must define a #{verb.upcase} operation" }
        end
      end

      # Validity: every request body must declare at least one media type and each
      # media type must carry a schema — a body without a schema is useless for
      # validation / client generation. Fully derived from the document.
      test 'every requestBody declares media types with a schema' do
        document = DocumentBuilder.new(locale: :en).call

        each_operation(document).each do |path, verb, operation|
          body = operation['requestBody']
          next if body.nil?

          content = body['content']

          assert content.is_a?(Hash) && content.any?, "#{verb.upcase} #{path} requestBody has no content"
          content.each do |media_type, media|
            assert media.is_a?(Hash) && media.key?('schema'),
                   "#{verb.upcase} #{path} requestBody (#{media_type}) is missing a schema"
          end
        end
      end

      # Management write endpoints must carry a JSON request body plus the write
      # error set incl. 422 (#50193: write endpoints carry requestBodySchemas and
      # matching response/error codes). Checks the concrete endpoints named
      # in the ticket scope so a regression on any of them fails the build.
      test 'management write endpoints carry a JSON body and 400/401/404/422 (#50193)' do
        document = DocumentBuilder.new(locale: :en).call
        expected_codes = ['400', '401', '404', '422']

        [
          ['post', '/endpoints'],
          ['post', '/external_links'],
          ['post', '/collections/create'],
          ['post', '/users/create'],
          ['patch', '/users/update'],
          ['post', '/external_sources/{external_source_id}']
        ].each do |verb, path|
          operation = document.dig('paths', path, verb)

          assert operation, "expected #{verb.upcase} #{path} to be documented"
          assert operation.dig('requestBody', 'content', 'application/json', 'schema'),
                 "#{verb.upcase} #{path} must carry a JSON request body schema"
          expected_codes.each do |code|
            assert operation.dig('responses', code), "#{verb.upcase} #{path} must document a #{code} response"
          end
        end
      end

      # config/translate path items are siblings of /api/v4 and must override the
      # server base; the self-describing GET /openapi is documented too.
      test 'config and translate path items override the server base (#50193)' do
        document = DocumentBuilder.new(locale: :en).call

        assert_equal '/api/config', document.dig('paths', '/openapi', 'servers', 0, 'url')
        assert document.dig('paths', '/openapi', 'get'), 'GET /openapi must be documented'

        if DataCycleCore::Feature['Translate']&.enabled?
          assert_equal '/api/translate', document.dig('paths', '/text', 'servers', 0, 'url'),
                       'translate path must be served from /api/translate'
        end
      end

      # Turn a Rails route spec into the candidate OpenAPI path templates: strip the
      # format/version/base noise, expand every optional "(…)" segment into a
      # present/absent variant and rewrite :param to {param}.
      def route_candidates(spec)
        path = spec.delete_suffix('(.:format)').delete_prefix('/api/v4').delete_prefix('(/:api_subversion)')
        expand_optionals(path).map { |variant|
          normalized = variant.gsub(/:(\w+)/, '{\1}').squeeze('/').chomp('/')
          normalized.empty? ? '/' : normalized
        }.uniq
      end

      # Recursively expand the first optional "(…)" group into with/without variants.
      def expand_optionals(path)
        open = path.index('(')
        return [path] if open.nil?

        depth = 0
        close = nil
        path[open..].each_char.with_index(open) do |char, index|
          depth += 1 if char == '('
          depth -= 1 if char == ')'
          if depth.zero?
            close = index
            break
          end
        end
        inner = path[(open + 1)...close]
        before = path[0...open]
        after = path[(close + 1)..]
        (expand_optionals(before + inner + after) + expand_optionals(before + after)).uniq
      end
    end
  end
end
