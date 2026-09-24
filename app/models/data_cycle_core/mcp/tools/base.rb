# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Domain base class for MCP tools. Deliberately simpler than MCP::Tool (SDK): an instance
      # method #call(arguments:, context:) rather than a class method -- Tools::Publication,
      # extended below, adapts it to the SDK interface.
      class Base
        extend DataCycleCore::Mcp::Tools::Publication

        class << self
          attr_accessor :tool_name
          attr_writer :description_key, :record_queries

          # Key of the tool description in config/locales/{de,en}.mcp.yml. Default: the tool_name.
          #
          # On every tool the two used to be the same string, declared by hand twice. That is not a
          # no-op in exactly one case: when a tool is renamed. The tool_name changes, the forgotten
          # description_key keeps pointing at the old locale entry -- and the tool silently carries
          # its predecessor's description instead of reporting a missing one.
          #
          # It stays settable for the case where several tools share one description.
          def description_key
            @description_key || tool_name
          end

          # Whether a call of this tool lands in the user's query history (Mcp::QueryLog).
          # Default true: every tool call IS a query by the user. The only exceptions are tools that
          # read the history themselves -- they would otherwise clutter it with their own lookups.
          def record_queries?
            @record_queries != false
          end

          # Declares the input_schema lazily: the block runs at the first actual access (e.g.
          # to_mcp_tool), not at class load -- some schemas call openapi_property, which builds the
          # OpenAPI document through a DB query. Evaluated eagerly in the class body, that would
          # couple Zeitwerk's eager_load (and every autoload) to a live, migrated database (see the
          # ticket about app:zeitwerk:check without a DB in CI).
          #
          # The cache is PER LOCALE, and the block receives it as an argument: the argument
          # descriptions are localized just like the tool description. A single cache
          # (@input_schema ||=) froze the language to that of the first access in the process -- an
          # English client got English tool descriptions but German argument descriptions, and which
          # language a process served depended on which request hit it first.
          def input_schema(locale: I18n.default_locale, &block)
            if block
              @input_schema_block = block
            else
              input_schemas[locale] ||= enforce_uuid_format(reject_unknown_arguments(@input_schema_block.call(locale)))
            end
          end

          # @return [Hash{Symbol => Hash}] the built schemas per locale.
          def input_schemas
            @input_schemas ||= {}
          end

          # Sets additionalProperties: false on the ROOT of every tool schema -- the mcp gem
          # validates with json_schemer against JSON Schema 2020-12, so the keyword takes effect.
          #
          # Without that boundary a mistyped or hallucinated parameter name is a no-op rather than an
          # error: "template_name" instead of "template_names" filters nothing and search_contents
          # answers with the endpoint's total -- read as an answer, a massively inflated number, with
          # applied_filters the only (easily missed) hint at it. With an LLM client the typo is the
          # likelier case, not the exception.
          #
          # Centrally here and not per tool, so a newly added tool cannot get through without the
          # boundary either (the same argument as for the query history in Publication#to_mcp_tool). Nested
          # objects stay the business of the respective schema: for some of them (search_contents'
          # schedule, the free-form data hash of the write tools) an open shape is intended.
          def reject_unknown_arguments(schema)
            return schema unless schema[:type] == 'object'
            return schema if schema.key?(:additionalProperties)

            schema.merge(additionalProperties: false)
          end

          # Makes every format: 'uuid' in a schema enforceable by placing Mcp::UUID_CONSTRAINTS
          # (pattern plus length) beside it -- the mcp gem validates with format: false, so the
          # keyword alone rejects nothing (rationale and measurement at Mcp::UUID_CONSTRAINTS).
          #
          # Central and recursive rather than at every property, for two reasons. First, the
          # declarations come from two sources: the path parameters from the OpenAPI document
          # (#openapi_property), the array parameters from the tool schema itself -- repeated at
          # every site, the assertion would be spread across 13 id parameters in 11 tools. Second,
          # the element shape does not sit at the same depth everywhere: for
          # classification_alias_id_groups (an array of arrays) it is two items levels below the
          # property, and precisely such an overlooked level is invisible from outside as a missing
          # check.
          #
          # An existing pattern is left untouched: a parameter demanding a NARROWER shape than an
          # arbitrary UUID should be allowed to keep it.
          def enforce_uuid_format(node)
            case node
            when Hash
              node = node.reverse_merge(DataCycleCore::Mcp::UUID_CONSTRAINTS) if node[:format] == 'uuid'
              node.transform_values { |value| enforce_uuid_format(value) }
            when Array
              node.map { |value| enforce_uuid_format(value) }
            else
              node
            end
          end

          # Localized tool description from config/locales/{de,en}.mcp.yml
          # (mcp.tools.<description_key>.description). interpolations e.g. endpoint_name:.
          def description(locale: I18n.default_locale, **interpolations)
            DataCycleCore::Mcp::Translations.t("tools.#{description_key}.description", locale:, **interpolations)
          end

          # Localized description of a tool argument from config/locales/{de,en}.mcp.yml
          # (mcp.tools.<description_key>.arguments.<path>). For nested objects path is dotted, e.g.
          # "attribute_condition.in".
          #
          # Separate from the tool description but in the same namespace: the argument texts used to
          # sit as German literals in the Ruby code and were thereby the only client-visible texts of
          # the server that could not be translated.
          def argument_description(path, locale:, **interpolations)
            DataCycleCore::Mcp::Translations.t("tools.#{description_key}.arguments.#{path}", locale:, **interpolations)
          end

          # Returns an input_schema property derived from the same OpenAPI document that
          # GET /api/config/openapi serves (DataCycleCore::Mcp::Document), instead of duplicating it
          # by hand. It raises on purpose when operation_id/param_name do not (any longer) exist --
          # silent drift between the tool schema and the OpenAPI documentation is worse than a
          # boot-time error.
          # @param locale [Symbol] language of the OpenAPI document -- without it the description
          # always came in I18n.default_locale, even for a client that asked for 'en'.
          # @param extra [String, nil] tool-specific hint appended to the OpenAPI description
          # (e.g. a precondition the generic OpenAPI text doesn't know about) -- localized through
          # #argument_description, not as a literal.
          def openapi_property(operation_id, param_name, locale: I18n.default_locale, extra: nil)
            schema = openapi_document(locale).path_parameter_schema(operation_id, param_name)
            # Name both causes: nil means "operation unknown OR parameter unknown", and a message
            # naming only the second sends the search in the wrong direction in the first case.
            raise "OpenAPI operation '#{operation_id}' is unknown or has no path parameter '#{param_name}' (tool: #{tool_name})" if schema.nil?

            # Deep, not shallow: #enforce_uuid_format matches node[:format], so a string-keyed
            # 'items' => { 'format' => 'uuid' } -- selectThings' uuid[] list, the first array
            # parameter read from OpenAPI -- would pass it by and ship unchecked UUIDs.
            property = schema.deep_symbolize_keys
            property[:description] = [property[:description], extra].compact.join(' ') if extra
            property
          end

          # The limit parameter's default as declared in the input_schema (JSON Schema `default`).
          #
          # That puts the value in exactly one place -- the place the client reads it from -- rather
          # than additionally as a literal in #call and a third time as prose ("default 20") in the
          # description. In suggest/suggest_by_title the literal value in #call was a hand-copied
          # second version of the OpenAPI default (Parameters.query_integer(default:)): change it
          # there and the schema derived from OpenAPI keeps naming the new value while the old one is
          # applied -- the same silent drift openapi_property was introduced against in the first
          # place.
          #
          # Language-independent although input_schema is not: what is localized are the
          # descriptions, not the default -- so the default language's schema suffices here.
          def default_limit
            input_schema.dig(:properties, :limit, :default)
          end

          # One OpenAPI document per language for ALL tools, rather than one per openapi_property
          # call: every instantiation builds the complete document (DocumentBuilder), and the tools
          # call openapi_property 16 times between them. The cache deliberately hangs off Base and
          # not off the respective subclass, or there would be one per tool. Lifetime as for the
          # schema cache above: one process, no invalidation -- a template change takes effect only
          # after a restart, exactly as before this change.
          def openapi_document(locale)
            Base.openapi_documents[locale] ||= DataCycleCore::Mcp::Document.new(locale:)
          end

          # @return [Hash{Symbol => DataCycleCore::Mcp::Document}] one document per locale, process-wide.
          def openapi_documents
            @openapi_documents ||= {}
          end
        end

        # Abstract: subclasses return the tool's result as a Hash/Array/String.
        def call(arguments:, context:)
          raise NotImplementedError, "#{self.class} must implement #call"
        end

        # Notices about THIS call, collected during #call and shipped in the envelope's `warnings`
        # (Tools::Publication) rather than inside the payload -- a client should see "the number you
        # are about to read rests on a filter that did not take effect" without first knowing which
        # nested key to look under.
        #
        # A collector rather than a return value, because the signal arises inside a collaborator
        # (Mcp::ConceptResolver, Mcp::FilterDescription) and would otherwise have to be threaded
        # back out through every return between there and here.
        def warnings
          @warnings ||= []
        end

        private

        # Not #warn: Kernel#warn already means "write to stderr" on every object, and a second
        # meaning on that name is what the same-name-same-meaning rule exists to prevent.
        def add_warning(*messages)
          warnings.concat(messages.flatten.compact_blank)
        end

        # The limit argument, otherwise the default declared in the schema (see .default_limit).
        #
        # It raises rather than falling to 0 when the tool declares no default at all: nil.to_i would
        # be a limit of 0, i.e. an empty hit list inside a successful response -- read as a result,
        # indistinguishable from "nothing found".
        def limit_from(arguments)
          limit = arguments[:limit].presence || self.class.default_limit
          raise "#{self.class} declares no 'default' for its limit property" if limit.nil?

          limit.to_i
        end

        # Language of a tool argument: the explicit argument, otherwise the mount's language
        # (Servers::Base puts it into the context), otherwise the instance's default language.
        #
        # No 'de' as a fallback in the gem: the language is instance-specific, and a fixed value is a
        # silent false assumption on every differently configured instance -- the query then runs
        # against the index of a language the endpoint does not carry at all and returns too few or
        # no hits without erroring.
        def locale_from(arguments, context)
          Array(arguments[:locale].presence || context[:locale] || I18n.default_locale).map(&:to_sym)
        end

        # Template names in the mount's result space (endpoint or instance-wide) -- so that
        # attribute discovery (list_attributes) and the attribute details in search_contents'
        # applied_filters see the same section (as Mcp::EndpointFacets does for the facets).
        def scope_template_names(context)
          context[:base_query].query.reorder(nil).reselect(:template_name).distinct.pluck(:template_name)
        end

        # Scheme representations for list_facets/browse_concept_schemes/facet_values: identity,
        # measured metrics (Mcp::ConceptSchemeMetrics) and the curated definition from
        # config/locales/{de,en}.mcp.yml.
        #
        # The plural is the entry point because the metrics are counted in one batch: calling
        # describe_scheme per tree would be an N+1 on the discovery path an LLM calls first.
        def describe_schemes(schemes, context)
          schemes = schemes.to_a
          metrics = DataCycleCore::Mcp::ConceptSchemeMetrics.new(scheme_ids: schemes.map(&:id), base_query: context[:base_query])

          schemes.map { |scheme| describe_scheme(scheme, metrics:) }
        end

        # Without a definition a client sees only the tree name and has to guess the dimension from
        # it -- "Feratel - Infrastrukturklassifizierungen" does not reveal that the dietary
        # categories hang there, "Regionen Vorarlberg" does not reveal that it is the touristic
        # rather than the administrative division. The guess is not recognisably wrong: the client
        # filters on a plausible tree, gets a plausible number and reports it without reservation.
        #
        # description is absent (rather than empty) when the tree has no definition -- which keeps
        # "not curated" distinguishable from "curated and empty". The metrics sit beside it and not
        # inside the text, because a definition cannot state its own age (see
        # Mcp::ConceptSchemeMetrics).
        def describe_scheme(scheme, metrics:)
          {
            id: scheme.id,
            name: scheme.name,
            **metrics.for(scheme.id),
            description: DataCycleCore::Mcp::Translations.concept_scheme_description(scheme.name)
          }.compact
        end

        # Normalises an ApiRenderer's response to a hash and thins it to a point ceiling -- see
        # Mcp::SeriesPayload for both. One place for statistics/timeseries/elevation_profile, which
        # all three take the same route.
        def rendered_hash(result)
          payload = DataCycleCore::Mcp::SeriesPayload.new(result)

          add_warning(payload.warning)

          payload.to_h
        end

        # Compact thing representation shared by search_contents/select_things -- enough
        # for an LLM to identify/pick a result without the full get_content payload.
        def summarize_thing(thing)
          {
            id: thing.id,
            template_name: thing.template_name,
            title: thing.attribute_to_h(thing.title_property_name),
            created_at: thing.created_at,
            updated_at: thing.updated_at
          }
        end
      end
    end
  end
end
