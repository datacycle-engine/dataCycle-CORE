# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # The requested filters of search_contents in APPLICATION ORDER, as a list of
    # [explain label, explain detail, lambda]. One entry per condition; filters that were not
    # requested are absent from the list, so the caller needs no further conditions and only folds
    # (see Tools::SearchContents#apply_filters).
    #
    # The order matters functionally and therefore sits as ONE list in one place (#to_a) rather than
    # as a sequence of ifs in the body of the tool:
    #
    # - template_names BEFORE the facets: narrows to the requested type before category facets take
    #   effect, which (depending on the tree) classify several types.
    # - place BEFORE near and the attributes: the geographic restriction is the cheaper one.
    #
    # A class of its own beside Mcp::FilterDescription (describes the resolved filter),
    # Mcp::FilterExplain (records its effect) and Mcp::AttributeFilter (attribute logic) -- which
    # keeps the tool itself restricted to applying and paginating.
    class FilterSteps
      # The default of include_subtree (true unless explicitly false) -- in one place, because two
      # sides need it: this class APPLIES it (which of the four classification scopes takes effect),
      # Mcp::FilterDescription REPORTS it. With the rule written twice, the response could state
      # "include_subtree: true" while filtering as though it were false -- a discrepancy that cannot
      # be spotted from the hit count alone and that applied_filters exists to rule out.
      def self.include_subtree?(arguments)
        arguments[:include_subtree] != false
      end

      # groups: the AND groups resolved by the tool (the same list goes into FilterDescription, so
      # description and application cannot drift apart).
      # place_scope: the resolved Mcp::GeoScope or nil -- an unresolvable place name yields NO step,
      # in which case the hit count is the unfiltered set (marked in the response through
      # applied_filters.place.resolved).
      def initialize(arguments:, groups:, place_scope: nil)
        @arguments = arguments
        @groups = groups
        @place_scope = place_scope
      end

      # Steps that can occur more than once (facet groups, relations) are unfolded into one entry
      # each -- which keeps the explain log at one line per condition.
      def to_a
        [
          query_step,
          template_step,
          *classification_group_steps,
          exclusion_step,
          attribute_step,
          schedule_step,
          place_step,
          near_step,
          *relation_steps
        ].compact
      end

      private

      def include_subtree?
        self.class.include_subtree?(@arguments)
      end

      # On a text search, sort by relevance (as the REST API does, sort_param_transformations.rb):
      # otherwise base_query would keep its sort_default order (boost/updated_at/id) and the most
      # relevant hits would not be on top. Without query, sort_default stays (deterministic).
      def query_step
        query = @arguments[:query].presence
        return if query.nil?

        ['query', query, ->(s) { s.fulltext_search(query).sort_fulltext_search('DESC', query) }]
      end

      def template_step
        templates = Array.wrap(@arguments[:template_names]).compact_blank
        return if templates.blank?

        ['template_names', templates.join(', '), ->(s) { s.template_names(templates) }]
      end

      # Each group is appended as its own scope call: the Filter::Common::Classification scopes are
      # cumulative, so applying them repeatedly combines the groups with AND while it stays OR
      # within a group. Without groups, "difficulty AND region AND category" could not be expressed
      # -- a shared list enlarged the result set instead of narrowing it.
      def classification_group_steps
        @groups.map.with_index do |ids, index|
          [
            'classification_group',
            "#{index + 1}/#{@groups.size}",
            ->(s) { apply_classification(s, ids, negate: false) }
          ]
        end
      end

      def exclusion_step
        ids = @arguments[:exclude_classification_alias_ids]
        return if ids.blank?

        ['excluded_classifications', nil, ->(s) { apply_classification(s, ids, negate: true) }]
      end

      def attribute_step
        conditions = @arguments[:attributes]
        return if conditions.blank?

        ['attributes', nil, ->(s) { DataCycleCore::Mcp::AttributeFilter.new.apply(s, conditions) }]
      end

      def schedule_step
        schedule = @arguments[:schedule]
        return if schedule.blank?

        ['schedule', nil, ->(s) { s.in_schedule(schedule) }]
      end

      # The level order of the cascade lives in Mcp::GeoScope, not here -- it is applied as one
      # condition, and nobody can reorder it.
      def place_step
        return if @place_scope.nil?

        ['place', @place_scope.anchor.internal_name, ->(s) { @place_scope.apply(s) }]
      end

      def near_step
        near = @arguments[:near].presence
        return if near.blank?

        # Make the nested hash indifferent itself rather than relying on the outer one being so:
        # when near sits with string keys inside a symbol-keyed hash, a dig(:near, :lat) silently
        # returns nil, geo_radius receives lon/lat/distance = nil and the radius filter comes out
        # ineffective -- with no error and no trace in applied_filters, where near still stands as
        # applied. The same safeguard as in Mcp::AttributeFilter (#build_filters), which normalises
        # its conditions itself for the same reason.
        near = near.to_h.with_indifferent_access
        radius = {
          'lon' => near[:lon],
          'lat' => near[:lat],
          'distance' => near[:radius_km],
          'unit' => 'km'
        }

        ['near', nil, ->(s) { s.geo_radius(radius) }]
      end

      def relation_steps
        Array.wrap(@arguments[:has_relations]).map { |name|
          ['has_relations', name, ->(s) { s.exists_graph_filter(nil, name, 'linked_items_in') }]
        } + Array.wrap(@arguments[:missing_relations]).map do |name|
          ['missing_relations', name, ->(s) { s.not_exists_graph_filter(nil, name, 'linked_items_in') }]
        end
      end

      # Maps the include/exclude × subtree/exact matrix onto the Filter::Common::Classification
      # scopes so the schema stays flat (two id lists + one boolean) instead of four id lists.
      def apply_classification(search, ids, negate:)
        return search if ids.blank?

        method = if negate
                   include_subtree? ? :not_concept_ids_with_subtree : :not_concept_ids_without_subtree
                 else
                   include_subtree? ? :concept_ids_with_subtree : :concept_ids_without_subtree
                 end

        search.public_send(method, ids)
      end
    end
  end
end
