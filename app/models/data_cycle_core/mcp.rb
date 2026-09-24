# frozen_string_literal: true

module DataCycleCore
  # MCP layer (Model Context Protocol): servers, tools and resources behind POST /api/mcp
  # (instance-wide) and POST /api/v4/endpoints/:id/mcp (endpoint-scoped) -- setup: docs/mcp/setup.md.
  module Mcp
    # The data scope of MCP queries, NOT an I18n locale. MCP is entity-centric: counts and searches
    # are meant to cover the WHOLE inventory, not only contents translated into the default locale.
    # 'all' switches the locale filter off (StoredFilter#default_query/#cached_query -> locale=nil ->
    # with_locale becomes a no-op; it is EXISTS-based, so nothing is counted twice) and titles still
    # render through the I18n fallback. Both mounts share the value: the same prompt must not report
    # two different totals on the global and the endpoint server because one of them silently scoped
    # to the default locale.
    QUERY_LANGUAGE = ['all'].freeze

    # The UUID shape as a JSON Schema assertion for the tool schemas. For that direction ONLY: the
    # codebase already has the server-side check in Ruby, which is String#uuid?
    # (StringExtension::UUID_REGEX) -- a second Ruby regexp beside it would be a duplicate that can
    # drift. Mcp::ToolContractTest pins that both representations accept the same input; a separate
    # representation is needed here because JSON Schema wants an ECMA-262 string, not a Ruby regexp.
    #
    # A concept NAME instead of the UUID ("wandern" rather than the alias id) is the likeliest LLM
    # mistake at the id parameters, and items: {type: 'string'} invites it. Unchecked it runs all the
    # way into the query: the ::uuid[] cast in Mcp::FilterDescription would then raise a
    # PG::InvalidTextRepresentation -- out of the very description meant to explain a wrong input,
    # and with a message a client cannot turn into a fix.
    #
    # The tools declare format: 'uuid' -- the same shape the OpenAPI document uses for those
    # parameters (OpenApi::Paths::Common.id_path_param), so the properties derived from it
    # (Tools::Base.openapi_property) need nothing of their own. What makes it enforceable is
    # Tools::Base.enforce_uuid_format, which adds UUID_CONSTRAINTS: the mcp gem compiles the tool
    # schemas with format: false (MCP::Tool::Schema#schemer), so a format keyword on its own has no
    # effect there and the input would pass despite the declaration.
    UUID_SHAPE = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

    # 8-4-4-4-12 hex digits plus four hyphens -- the canonical UUID length.
    UUID_LENGTH = 36

    # minLength/maxLength are part of the assertion, not belt and braces: the pattern alone does not
    # hold the promise. json_schemer translates it into a RUBY regexp, where ^ and $ are LINE
    # anchors -- so "wandern\n<uuid>" satisfies "^<uuid>$" and would pass (measured with
    # json_schemer 2.5.0). \A/\z in the pattern would not be a fix but a false promise to every
    # client outside Ruby: JSON Schema expects ECMA-262 syntax, where \A means the literal "A". The
    # length settles the case portably -- at exactly 36 characters there is no room for a newline
    # beside a fully matched line.
    UUID_CONSTRAINTS = {
      pattern: "^#{UUID_SHAPE}$",
      minLength: UUID_LENGTH,
      maxLength: UUID_LENGTH
    }.freeze
  end
end
