# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # What a tool publishes to a client, and how a domain tool becomes one: its annotations, the
      # response envelope every tool shares, and the MCP::Tool that Servers::Base hands to
      # MCP::Server.
      #
      # Extended into Tools::Base rather than living there, which keeps that class what its own
      # comment calls it -- the DOMAIN base class, an instance #call(arguments:, context:) plus the
      # helpers a tool body needs. Everything here is the adapter to the SDK, and the two together
      # had grown past 300 lines.
      module Publication
        # Behavioural hints a client may act on WITHOUT calling the tool (offer it unasked, retry a
        # failed call, warn before a write). The default is the read case; create_content and
        # update_content override it.
        #
        # Declared rather than left to the gem, whose defaults are the spec's worst case
        # (destructive, non-idempotent, open world) -- undeclared, every read tool here would
        # announce itself as writing. open_world_hint: false throughout: both mounts read this
        # instance's own database and reach no service outside it.
        DEFAULT_ANNOTATIONS = { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false }.freeze

        # The response envelope every tool shares: `ok` beside the tool's own payload under `data`.
        # Before it, a tool's result WAS the response, so a client had to learn 25 top-level shapes
        # and could not tell a status key from a payload key -- get_schema answers with `error` and
        # list_facets with `schemes`, at the same level and indistinguishable to a reader.
        #
        # data is deliberately unconstrained: the payloads genuinely differ, and once
        # validate_tool_call_results is switched on (off in the gem by default) a narrower type
        # would turn a renderer that returns an array into a failed call rather than a wrong schema.
        #
        # warnings is absent rather than empty when a call has none: a key that is [] on almost
        # every response trains a client to skip it, and the one call that does warn then reads like
        # all the others.
        #
        # No error case here -- the gem skips validation for isError responses
        # (Server#validate_tool_call_result!), and errors travel as {ok: false, errors: [...]},
        # which keeps the {source:, title:, detail:} shape Mcp::ErrorMapper shares with the REST API.
        OUTPUT_SCHEMA = {
          type: 'object',
          properties: {
            ok: { type: 'boolean' },
            data: { description: "the tool's payload" },
            warnings: { type: 'array', items: { type: 'string' } }
          },
          required: ['ok', 'data']
        }.freeze

        # Declared per tool as `self.annotations = {...}`; see #annotations for the merge.
        attr_writer :annotations

        # DEFAULT_ANNOTATIONS merged with a subclass's override, so a writing tool declares only what
        # differs from the read case.
        def annotations
          DEFAULT_ANNOTATIONS.merge(@annotations.to_h)
        end

        # Builds an MCP::Tool subclass that MCP::Server.new(tools: [...]) can consume directly.
        # description: the already resolved (localized, interpolated) description.
        #
        # The query history runs along here TOO (Mcp::QueryLog): this block is the only place every
        # tool call of both mounts passes through -- in the tools themselves the same thing would
        # have to be repeated 20 times and a new tool would silently arrive without a history.
        def to_mcp_tool(description:, locale: I18n.default_locale)
          domain_tool_class = self

          MCP::Tool.define(
            name: tool_name,
            description:,
            input_schema: input_schema(locale:),
            output_schema: OUTPUT_SCHEMA,
            annotations:
          ) do |server_context:, **arguments|
            # The call runs in the mount's language. The API controllers do NOT set I18n.locale
            # (see Mcp::ContentWriter#with_write_locale), so it stayed the instance's default
            # language -- and everything that draws its language from the environment therefore
            # answered in German while the tool and argument descriptions of the same server were
            # already English: the names of the concepts and trees (Concept and ConceptScheme
            # translate `name` through mobility via I18n.locale), the name
            # search in Mcp::ConceptResolver (name_i18n ->> locale) and the curated tree
            # definitions (Mcp::Translations.concept_scheme_description).
            #
            # Here and not per tool, for the same reason as the query history below: this is the
            # only place every tool call of both mounts passes through -- repeated per tool, a
            # newly added one would silently come back out in the default language again.
            # with_indifferent_access, because the arguments arrive symbolized ONLY at the top
            # level: the mcp gem splats them as keywords (**arguments), but nested objects stay the
            # string-keyed hashes from the JSON. Measured with near: {"lat" => 47.1}:
            # arguments.keys == [:near], arguments[:near].keys == ["lat", "lon", "radius_km"],
            # arguments[:near][:lat] == nil.
            #
            # That is the most dangerous kind of error in this layer, because it does NOT raise: a
            # dig with a symbol returns nil, the filter or the sort comes out ineffective, and
            # applied_filters still reports it as applied. Measured with
            # sort: {attribute: "distance"} + near -- geo_value produced [nil, nil],
            # Filter::Sortable::Proximity#sort_proximity_geographic discards invalid coordinates
            # silently (`return self unless valid_geographic_coordinates?`), and the client got an
            # unsorted list presenting itself as a distance ranking.
            #
            # Two places had already guarded this individually (Mcp::AttributeFilter
            # #build_filters, Mcp::FilterSteps#near_step), a third had not -- hence here, at the one
            # place every tool call of both mounts passes through. The local normalisations stay:
            # they keep their classes sound for direct calls too.
            arguments = arguments.with_indifferent_access

            tool = domain_tool_class.new
            result = I18n.with_locale(locale) { tool.call(arguments:, context: server_context) }

            DataCycleCore::Mcp::QueryLog.record(context: server_context, tool: domain_tool_class, arguments:, result:)

            envelope = { ok: true, data: result, warnings: tool.warnings.presence }.compact

            # Both halves carry the SAME envelope: the text block is what a client without
            # structuredContent support reads, and the two used to diverge -- a String result went
            # out as bare text with no structured content beside it at all.
            MCP::Tool::Response.new(
              [{ type: 'text', text: JSON.generate(envelope) }],
              structured_content: envelope
            )
          rescue StandardError => e
            # locale as for the result: an error message is the text a client shows the user, and
            # it was the only client-visible text of this server hard-wired to English -- on a
            # German mount too.
            error_payload = DataCycleCore::Mcp::ErrorMapper.call(e, locale:)

            # The failed call belongs in the history as well: otherwise a follow-up call sees only
            # the successful queries and repeats exactly the error the user already had.
            DataCycleCore::Mcp::QueryLog.record(context: server_context, tool: domain_tool_class, arguments:, error: e)

            envelope = { ok: false, **error_payload }

            MCP::Tool::Response.new(
              [{ type: 'text', text: JSON.generate(envelope) }],
              error: true,
              structured_content: envelope
            )
          end
        end
      end
    end
  end
end
