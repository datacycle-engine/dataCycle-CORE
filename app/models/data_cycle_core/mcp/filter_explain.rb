# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Records the cumulative hit count after every applied filter step -- the answer to "why does my
    # colleague get a different number?". applied_filters shows WHAT was filtered; explain shows HOW
    # MUCH each individual condition removes, and thereby pins the discrepancy to one step instead of
    # to the filter as a whole.
    #
    # Example (restaurants with vegan options): endpoint 19,831 -> category 849 -> vegan 81 ->
    # Vorarlberg 79. The last step costs 2 hits because two food establishments carry no
    # administrative-unit assignment although their address is in Vorarlberg -- a data gap that
    # otherwise stays invisible behind the filter result.
    #
    # Deliberately opt-in (search_contents: explain: true): every step costs its own COUNT over the
    # set filtered so far, and that is diagnostics, which should not make every search more
    # expensive.
    class FilterExplain
      def initialize(enabled:)
        @enabled = enabled
        @steps = []
      end

      # So that the remaining diagnostic numbers of a response hang off this one switch too --
      # applied_filters.place.coverage costs a COUNT per cascade level, opt-in for the same reason
      # as the steps here (see Tools::SearchContents#place_coverage).
      def enabled?
        @enabled
      end

      # filter: name of the step, detail: optional refinement (e.g. the group number).
      # search: the filter state AFTER the step was applied.
      def record(filter, search, detail: nil)
        return unless @enabled

        @steps << { filter:, detail:, count: search.count }.compact
      end

      # nil (rather than []) when disabled or empty, so applied_filters omits the key.
      def steps
        @steps.presence
      end
    end
  end
end
