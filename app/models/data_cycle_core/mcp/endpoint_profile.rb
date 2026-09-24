# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # The profile of ONE endpoint (or of the instance-wide result space): identity, content volume,
    # templates, the detail dimensions it carries (Mcp::ContentDetails) and -- derived from those --
    # a verdict on every tool of this mount.
    #
    # The verdict is the purpose of the class. In tools/list a client sees WHICH tools exist, but not
    # which of them answer anything in THIS endpoint: timeseries and elevation_profile stand there
    # beside search_contents, and whether they ever return a value here depends on the data, not on
    # the tool list. Without the verdict a client tries them out, gets a 404 or an empty response and
    # reads it as a mistake of its own -- rather than as an empty dimension. That is why every tool
    # is accompanied by the dimension it hangs off, together with that dimension's measured
    # occupancy.
    class EndpointProfile
      # Tools that are ALWAYS the right answer to "how do I start here", provided the endpoint
      # carries any contents at all: search, detail retrieval, type list. They hang off no single
      # dimension and would be filed under also-rans as "available".
      CORE_TOOLS = ['search_contents', 'get_content', 'list_templates'].freeze

      # The SHARE of contents from which a measured dimension counts as occupied and its tool is
      # therefore recommended. Previously the absolute number decided that (positive?), and a single
      # content sufficed: in the 'KulinarischesErbe' endpoint 1 of 110 contents carried geodata
      # (share 0.009) and resolve_place still stood there as a recommendation -- with 109 of 110 hits
      # it contributes nothing. The share is the figure that separates that, not the count: 2,491
      # contents with elevation data are a promise in an endpoint with 2,510 contents and a footnote
      # in one with 260,897 (Mcp::ContentDetails#measured already computes it).
      #
      # Deliberately LOW, because the denominator is the entire content volume and instance-wide that
      # is dominated by 220,957 images: 22,970 contents carry geodata there and are therefore only
      # 8.8% -- a threshold above 0.05 would downgrade resolve_place on the very mount where it is
      # the right answer to every place question.
      MIN_DETAIL_SHARE = 0.05

      # Tool -> dimension, built from Mcp::ContentDetails::TOOLS. Not maintained as a second table:
      # the two would drift apart with every new tool, and the consequence would not be an error but
      # a tool silently recommended as "available" although its dimension does not occur in the
      # endpoint at all.
      TOOL_DETAILS = DataCycleCore::Mcp::ContentDetails::TOOLS
        .flat_map { |detail, tools| tools.map { |tool| [tool, detail.to_s] } }
        .to_h
        .freeze

      # @param stored_filter [DataCycleCore::StoredFilter, nil] nil = the instance-wide result space
      # @param base_query [DataCycleCore::Filter::Search] result space of the described endpoint
      # @param tool_names [Array<String>] the tools of THIS mount (Servers::Base puts them into the
      #   context) -- not every tool of the gem: download exists only on the endpoint mount,
      #   list_endpoints only instance-wide, and the writing ones only under write_enabled.
      # @param queryable_here [Boolean] whether the described endpoint is the result space of THIS
      #   mount (see #endpoint)
      # @param locale [Symbol] language of the label for the instance-wide result space
      def initialize(stored_filter:, base_query:, tool_names:, queryable_here:, locale:)
        @stored_filter = stored_filter
        @base_query = base_query
        @tool_names = tool_names
        @queryable_here = queryable_here
        @locale = locale
      end

      # @return [Hash] { endpoint:, content_count:, templates:, details:, tools: }
      def call
        {
          endpoint:,
          content_count:,
          templates:,
          details:,
          tools:
        }
      end

      private

      # queryable_here: a FOREIGN endpoint described through endpoint_id is not queryable from this
      # mount -- search_contents and friends keep running over the result space of THIS server.
      # Without that flag a client reads the profile as a promise and subsequently reports numbers
      # from the wrong endpoint; list_endpoints already says that every endpoint needs its own MCP
      # server configuration.
      #
      # The instance-wide result space has NO name and is not given one here either: it is not an
      # endpoint, and an invented name ("Alle Inhalte") would be indistinguishable from a real
      # endpoint name. Instead scope: 'global' plus the description the tool descriptions of this
      # mount use as well (Mcp::Translations).
      def endpoint
        return { scope: 'global', description: DataCycleCore::Mcp::Translations.t('scope.global', locale: @locale), queryable_here: @queryable_here } if @stored_filter.nil?

        {
          id: @stored_filter.id,
          name: @stored_filter.name,
          # description_stripped as in Tools::ListEndpoints: the editorial description is maintained
          # as HTML in the backend, and markup is only noise to a client.
          description: @stored_filter.description_stripped.presence,
          # The maintained language from the DATABASE, not from the object: building the result space
          # sets `filter.language` to Mcp::QUERY_LANGUAGE ('all') -- in the controller on the endpoint
          # mount (FilterConcern#build_search_query), in Mcp::ApiScope for a foreign endpoint_id --
          # and both happen before this line. Read from the object, describe_endpoint therefore
          # reported 'all' for EVERY endpoint and contradicted list_endpoints, which reads the same
          # value from an untouched record (measured: 'TEST - Sennerei' is maintained as ['de'] and
          # was reported as ['all']).
          language: @stored_filter.language_in_database.presence,
          queryable_here: @queryable_here
        }.compact
      end

      def content_count
        @content_count ||= @base_query.query.count
      end

      def templates
        @templates ||= DataCycleCore::Mcp::TemplateCounts.call(@base_query)
      end

      # The tools per dimension are restricted to those of this mount: for the classifications the
      # catalogue also names list_concepts, which exists only instance-wide. Unfiltered, a tool would
      # stand recommended on the endpoint mount that does not appear in its tools/list at all -- the
      # client calls it and gets "Method not found" in reply to a recommendation by the server.
      def details
        @details ||= DataCycleCore::Mcp::ContentDetails.new(
          base_query: @base_query,
          stored_filter: @stored_filter,
          template_names: templates.pluck(:template_name),
          content_count:
        ).to_a.map { |entry| entry.merge(tools: entry[:tools] & @tool_names) }
      end

      # One verdict per tool of the mount. Three levels, so that "does not work" and "works, but is
      # nothing special here" stay distinguishable:
      #
      #   recommended  carries data in this endpoint (a core tool, or a dimension at or above
      #                MIN_DETAIL_SHARE)
      #   available    runs, but is not the entry point here: either the tool hangs off no measured
      #                dimension (e.g. suggest, statistics -- then "detail" is absent), or its
      #                dimension is occupied but too thin for a recommendation (then "detail" names
      #                it, and its "share" in details says how thin)
      #   no_data      the tool's dimension is not declared here, or EMPTY -- every call answers
      #                empty, which is not an error and not worth repeating
      #
      # A thinly occupied dimension is explicitly "available" and NOT "no_data": no_data is the
      # promise that every call answers empty, and that would be wrong with a single content carrying
      # geodata -- a client would then stop calling the tool even for the content it answers for. The
      # two available cases stay distinguishable at the "detail" field.
      def tools
        @tool_names.map do |tool|
          { tool:, status: status_for(tool), detail: TOOL_DETAILS[tool] }.compact
        end
      end

      # An empty endpoint makes EVERY tool hopeless, the core tools included -- otherwise the profile
      # recommends search_contents on a result space without a single content.
      def status_for(tool)
        return 'no_data' if content_count.zero?

        detail = TOOL_DETAILS[tool]
        return CORE_TOOLS.include?(tool) ? 'recommended' : 'available' if detail.nil?

        entry = details.find { |d| d[:detail] == detail }
        return 'no_data' unless populated?(entry)

        share_of(entry) >= MIN_DETAIL_SHARE ? 'recommended' : 'available'
      end

      # Whether the dimension is occupied at all -- the question no_data hangs off, and it is decided
      # on the ABSOLUTE numbers, not on the share: share is rounded to three places
      # (ContentDetails#measured), so 1 content out of 260,897 stands there as 0.0. Decided on the
      # share, that would mean no_data, i.e. the promise "every call answers empty" -- but for that
      # one content the tool does answer, and after a no_data a client would stop calling it for that
      # content too. Occupied means something different per dimension: for the measured ones,
      # contents carrying the detail; for classifications/attributes, the number of offerable trees
      # or attributes. A dimension that is not declared at all is missing from details and is
      # therefore not occupied.
      def populated?(entry)
        return false if entry.nil?

        entry.values_at(:content_count, :concept_schemes, :filterable_attributes).compact.sum.positive?
      end

      # The share MIN_DETAIL_SHARE compares against. The measured dimensions already carry it as
      # "share" (computed against the endpoint's content volume, ContentDetails#measured).
      # classifications/attributes count offerable TREES or attributes rather than contents and have
      # no share -- one would make no sense there either (4 trees out of how many?) and the question
      # does not arise: a single offerable tree makes facet_values worthwhile. For them, "present"
      # therefore means full coverage.
      def share_of(entry)
        entry[:share] || 1.0
      end
    end
  end
end
