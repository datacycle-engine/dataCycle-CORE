# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Builds the applied_filters object of the search_contents response: the RESOLVED filter, not an
    # echo of the raw arguments -- concept names for the UUIDs, the concepts pulled in by subtree,
    # and the unit of the attribute filters.
    #
    # Without it a hit count is not verifiable. Two clients mapping the same question onto concepts
    # differently return two plausible numbers, and the difference is invisible in the response --
    # it has to be reconstructed by recomputing. Measured on "restaurants in Vorarlberg with vegan
    # options": 17 to 194 hits, depending on the choice of vegan variant, the category boundary and
    # full text versus facet.
    #
    # A class of its own (not a private part of Tools::SearchContents), so the tool stays restricted
    # to applying filters -- as Mcp::AttributeFilter does for the filter logic itself.
    class FilterDescription
      # How many subtree concepts are named per group. Capped, because a subtree can span several
      # thousand concepts (administrative units); the total sits beside it so the truncation stays
      # visible and is not taken for the full picture.
      SUBTREE_SAMPLE_LIMIT = 25

      # groups: the AND groups resolved by the tool (the grouping logic stays there, in one place).
      # units: attribute name => unit, from the same discovery list_attributes ships.
      # place_scope: the resolved Mcp::GeoScope (nil when no place was passed OR the place name was
      # not resolvable -- #describe_place distinguishes the two cases).
      # sort: the resolved Mcp::SortScope (nil = default ordering). It is in the response because a
      # ranking without a named sort criterion and its unit cannot be followed.
      def initialize(arguments:, groups:, include_subtree:, units: {}, place_scope: nil, place_coverage: nil, sort: nil)
        @arguments = arguments
        @groups = groups
        @include_subtree = include_subtree
        @units = units
        @place_scope = place_scope
        @place_coverage = place_coverage
        @sort = sort
      end

      # explain_steps: optional log of the cumulative hit count per filter step
      # (see Mcp::FilterExplain) -- shows which condition removes how much.
      def to_h(explain_steps: nil)
        {
          template_names: template_names.presence,
          classification_groups: @groups.presence&.map { |ids| describe_classifications(ids) },
          excluded_classifications: excluded.presence && describe_classifications(excluded),
          attributes: describe_attributes,
          query: @arguments[:query].presence,
          place: describe_place,
          near: @arguments[:near].presence,
          schedule: @arguments[:schedule].presence,
          has_relations: list(:has_relations).presence,
          missing_relations: list(:missing_relations).presence,
          sort: @sort.presence,
          explain: explain_steps
        }.compact
      end

      # Every passed concept id for which no (undeleted) concept exists, across the AND groups AND
      # the exclusions -- the flat signal for the envelope's warnings (Tools::SearchContents).
      #
      # Resolved here in ONE lookup so that "unresolved = requested minus found" has a single place:
      # the per-group unresolved_ids in #to_h is a slice of this set, and stays there because it is
      # the only place that says WHICH condition lost them.
      def unresolved_ids
        @unresolved_ids ||= begin
          requested = (@groups.flatten + excluded).map(&:to_s).uniq

          requested.blank? ? [] : requested - concept_names(requested).pluck(:id)
        end
      end

      # The requested place name when it resolved to nothing, nil otherwise. Public for the same
      # reason as #unresolved_ids: search_contents builds the envelope warning from it, and a second
      # "requested but unresolved" test there would be free to drift away from #describe_place.
      def unresolved_place
        return if @place_scope.present?

        @arguments[:place].presence
      end

      private

      def template_names
        list(:template_names)
      end

      # An unresolvable place name MUST appear in the response: the filter then does not take
      # effect, the hit count is the unfiltered total and without this hint would read as "that many
      # exist in <place>" -- the same trap as unresolved_ids on the facets.
      # coverage names the hits per cascade level: a number coming mostly from :address rests on
      # weaker evidence than one from :classification.
      def describe_place
        requested = @arguments[:place].presence
        return if requested.nil?
        return { requested:, resolved: false, unresolved_place: } if unresolved_place.present?

        @place_scope.to_h.merge(requested:, resolved: true, coverage: @place_coverage).compact
      end

      def excluded
        list(:exclude_classification_alias_ids)
      end

      def list(key)
        Array.wrap(@arguments[key]).compact_blank
      end

      # concepts: the directly passed concepts with their names. subtree_concepts: what
      # include_subtree additionally pulls in -- exactly the set that can widen a group
      # unintentionally. unresolved_ids is this group's slice of #unresolved_ids -- passed UUIDs for
      # which no (undeleted) concept exists, which filter nothing silently, typically a
      # classification id confused with an alias id.
      def describe_classifications(ids)
        concepts = concept_names(ids)
        unresolved = ids.map(&:to_s) & unresolved_ids
        descriptor = { concepts:, include_subtree: @include_subtree }
        descriptor[:unresolved_ids] = unresolved if unresolved.present?

        return descriptor unless @include_subtree

        descendant_ids = descendant_ids_for(ids)
        return descriptor if descendant_ids.blank?

        descriptor[:subtree_concepts] = concept_names(descendant_ids, limit: SUBTREE_SAMPLE_LIMIT)
        descriptor[:subtree_concept_count] = descendant_ids.size
        descriptor[:subtree_concepts_truncated] = descendant_ids.size > SUBTREE_SAMPLE_LIMIT
        descriptor
      end

      # The order comes from the default_scope (order_a, id) and is therefore stable even with a
      # limit set -- a truncated sample stays the same between two calls.
      def concept_names(ids, limit: nil)
        scope = DataCycleCore::Concept.where(id: ids)
        scope = scope.limit(limit) if limit

        scope.map { |a| { id: a.id, name: a.name } }
      end

      # ancestor_ids holds only true ancestors (not the node itself), so the result is the set of
      # descendants without the passed concepts.
      #
      # Non-UUIDs have to go BEFORE the query: the ::uuid[] cast raises a
      # PG::InvalidTextRepresentation on them. The tool schemas now reject them up front
      # (Mcp::UUID_CONSTRAINTS), but the check stays here -- the filter step itself tolerates the
      # value (0 hits, no error), and the description of the filter must not be the only place that
      # fails on an input. The value then appears through #describe_classifications in
      # unresolved_ids, which is exactly where it belongs.
      def descendant_ids_for(ids)
        uuids = ids.map(&:to_s).select(&:uuid?)
        return [] if uuids.blank?

        DataCycleCore::ConceptPath
          .where('ancestor_ids && ARRAY[?]::uuid[]', uuids)
          .pluck(:id)
      end

      # "max: 15000" on its own cannot be interpreted, "max: 15000, unit: m" can -- the classic
      # failure is "under 15 km" passed as max: 15 against a metre attribute.
      def describe_attributes
        conditions = list(:attributes)
        return if conditions.blank?

        conditions.map do |condition|
          condition = condition.to_h.deep_symbolize_keys
          attribute = condition[:attribute]

          {
            attribute:,
            unit: @units[attribute.to_s],
            in: condition[:in].presence,
            not_in: condition[:not_in].presence
          }.compact
        end
      end
    end
  end
end
