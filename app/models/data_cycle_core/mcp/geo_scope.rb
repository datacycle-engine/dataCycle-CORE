# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Deterministic geo resolution for MCP tools: a place name is ALWAYS mapped onto a filter in
    # the same order -- classification tree, then geo_regions, then address. The order is
    # deliberately NOT configurable and appears in NO input_schema: an LLM should not be able to
    # choose the resolution strategy, only to pass a place name (the same principle as
    # Mcp::Tools::UniversalLookup, which tries Thing/ConceptScheme/Concept/Schedule in a fixed
    # sequence).
    #
    # The cascade applies PER CONTENT, not globally. Globally ("does the tree node exist at all?")
    # it would have no effect: measured in vcloud-dev, only 3608 of 5996 LodgingBusiness carry an
    # assignment in the administrative tree, and 2066 things have latitude/longitude = 0/0 and are
    # therefore locatable neither through the tree nor through geo_regions -- only through their
    # address. Tree only: 3601 hits, full cascade: 5926.
    #
    # Those 5926 assume configured postal_code_patterns (see #postal_code_pattern); the gem ships
    # them empty because postal-code spaces are instance-specific. Without them it is 5356 -- and
    # what is missing then is exactly the localities that do not exist as a concept in the tree.
    class GeoScope
      # Fixed resolution order. Not configurable -- see the class comment.
      STAGES = [:classification, :geo_regions, :address].freeze

      class << self
        # Resolves a place name to the first match in the configured resolution trees (order =
        # configuration order, so ambiguous names resolve deterministically: "Vorarlberg" exists in
        # four trees in vcloud-dev).
        # @return [GeoScope, nil] nil when the name occurs in no tree.
        def resolve(name)
          return nil if name.blank?
          # Without an active feature or without a configured resolution tree there is no cascade:
          # nil means "place not resolvable" to the callers, the place filter stays ineffective and
          # resolve_place says so explicitly -- rather than silently counting over the whole set.
          return nil unless DataCycleCore::Feature::Mcp.geo_enabled?

          DataCycleCore::Feature::Mcp.resolution_trees.each do |tree_name|
            schemes_for(tree_name).each do |scheme|
              anchor = anchor_in(scheme, name)
              return new(anchor:, concept_scheme: scheme) if anchor
            end
          end

          nil
        end

        # Concepts of ONE scheme -- the starting point for both the name resolution and the
        # geo_regions candidates.
        def concepts_in_schemes(concept_scheme_ids)
          DataCycleCore::Concept.where(concept_scheme_id: concept_scheme_ids)
        end

        private

        # A tree name is NOT unique in the database (in vcloud-dev "Kulinarisches Erbe" exists
        # twice). find_by would take an arbitrary one of them, and which that is is decided by the
        # query plan -- so the resolution would hang on exactly the chance that STAGES and the
        # configuration order exist to rule out. Hence all identically named labels in a stable
        # order, and the first one with an anchor wins.
        def schemes_for(tree_name)
          DataCycleCore::ConceptScheme.where(name: tree_name).order(:created_at, :id)
        end

        # An exact (case-insensitive) name match. Deliberately NO LIKE/ILIKE: the place name comes
        # from an LLM, and in LIKE semantics '%' and '_' are wildcards -- place: "%" resolved to an
        # arbitrary concept, "Vorarl%" to "Vorarlberg". That would bring back exactly the substring
        # resolution this class rules out: the filter shifts silently to another region, and the hit
        # count looks plausible.
        def anchor_in(scheme, name)
          concepts_in_schemes(scheme.id).find_by('lower(concepts.internal_name) = lower(?)', name)
        end
      end

      attr_reader :anchor, :concept_scheme

      def initialize(anchor:, concept_scheme:)
        @anchor = anchor
        @concept_scheme = concept_scheme
      end

      # The resolved place as a descriptor for the tool response.
      def to_h
        {
          place: anchor.internal_name,
          concept_id: anchor.id,
          concept_scheme: concept_scheme.name,
          stages: STAGES.map { |stage| { stage:, resolved: stage_resolved?(stage) } }
        }
      end

      # Appends the cascade to a Filter::Search as a single WHERE condition.
      # Precedence sits inside the condition itself (see #cascade_sql), not in the call order -- so
      # the caller cannot reorder the stages.
      def apply(search)
        search.where(cascade_sql)
      end

      # How many contents of the (already filtered) set were assigned through which stage.
      # It belongs in the tool response: a number coming mostly from the address stage rests on
      # weaker evidence than one from the classification tree, and that has to be visible.
      def coverage(search)
        STAGES.index_with { |stage| search.where(stage_sql(stage)).count }
      end

      private

      # An else branch instead of a silent nil: a new stage in STAGES without a branch here would
      # otherwise return nil, which #cascade_sql would interpolate into " OR " -- broken SQL instead
      # of a clear error.
      def stage_resolved?(stage)
        case stage
        when :classification then subtree_concept_ids.present?
        when :geo_regions then geo_region_concept_ids.present?
        when :address then localities.present? || postal_code_pattern.present?
        else raise ArgumentError, "unknown geo scope stage #{stage.inspect}"
        end
      end

      # match1 OR (NOT present1 AND (match3 OR (NOT present3 AND match2)))
      def cascade_sql
        "(#{STAGES.map { |stage| stage_sql(stage) }.join(' OR ')})"
      end

      # The condition of ONE stage, including the precedence exclusions of the stages above it.
      # That makes the stages disjoint: coverage adds up to the total hit count and shows which
      # source actually carried a hit.
      def stage_sql(stage)
        case stage
        when :classification
          match_classification
        when :geo_regions
          "(NOT #{present_classification} AND #{match_geo_regions})"
        when :address
          "(NOT #{present_classification} AND NOT #{present_geo_regions} AND #{match_address})"
        else raise ArgumentError, "unknown geo scope stage #{stage.inspect}"
        end
      end

      def match_classification
        concept_ids_exists(subtree_concept_ids)
      end

      def present_classification
        concept_scheme_exists([concept_scheme.id])
      end

      def match_geo_regions
        concept_ids_exists(geo_region_concept_ids)
      end

      # A stage may only block the next one when it can decide anything for THIS place at all. The
      # geo_regions trees are coarser than the municipal level: for "Gemeinde Egg" not a single
      # region polygon lies inside the place, so geo_region_concept_ids is empty. Were the stage to
      # gate anyway, the 7 Egg accommodations would drop out of the result -- they carry no
      # administrative assignment, would be findable through their address, but hang off the region
      # "Bregenzerwald", which spans the whole district. The result would be 0 instead of 7.
      def present_geo_regions
        return 'FALSE' if geo_region_concept_ids.blank?

        concept_scheme_exists(geo_region_scheme_ids)
      end

      def match_address
        conditions = []
        conditions << "#{address_field('address_locality')} IN (#{quote_list(localities)})" if localities.present?
        conditions << "#{address_field('postal_code')} ~ #{quote(postal_code_pattern)}" if postal_code_pattern.present?
        return 'FALSE' if conditions.empty?

        "(#{conditions.join(' OR ')})"
      end

      # address lives in things.metadata, NOT in thing_translations.content -- a search in the
      # translations silently returns 0 hits although thing.to_h['address'] is populated.
      def address_field(key)
        "things.metadata->'address'->>#{quote(key)}"
      end

      def concept_ids_exists(ids)
        ccc_exists('concept_id', ids)
      end

      # "Does the content have ANY assignment in this scheme?" -- the fallthrough condition of the
      # cascade. Through concept_scheme_id rather than through the concept list, so that even large
      # schemes need not be materialised as an IN list.
      def concept_scheme_exists(scheme_ids)
        ccc_exists('concept_scheme_id', scheme_ids)
      end

      # Every stage asks the same question of the same table and differs only in the column -- one
      # formulation, so the stages cannot drift apart.
      def ccc_exists(column, ids)
        return 'FALSE' if ids.blank?

        'EXISTS (SELECT 1 FROM collected_concept_contents ccc WHERE ccc.thing_id = things.id ' \
          "AND ccc.#{column} IN (#{quote_list(ids)}))"
      end

      # Anchor plus all descendants: full_path_ids holds a concept's path up to the root, so a
      # concept with the anchor in it lies in the subtree (the anchor itself included).
      #
      # Deliberately concept_paths and NOT concept_paths_transitive: the transitive variant hangs
      # off the transitive_classification_path feature and is empty without it -- the cascade would
      # then silently return 0 hits from stage 1.
      # Mcp::FilterDescription uses ConceptPath for the same reason.
      def subtree_concept_ids
        @subtree_concept_ids ||= DataCycleCore::ConceptPath
          .where('? = ANY(full_path_ids)', anchor.id)
          .distinct
          .pluck(:id)
      end

      # Stage 3 resolves by polygon containment, not by name equality: measured in vcloud-dev not a
      # single geo_regions concept carries the name "Vorarlberg", yet 20 of 22 lie inside the
      # Vorarlberg polygon. A name comparison would have returned 0 hits here.
      # What is tested is the region's representative point, not the whole polygon: ST_Covers
      # against the full area failed because the geo_regions polygons come from a different source
      # than the administrative boundaries and stick out minimally at the edges -- 2 of 22 regions
      # dropped out of the resolution. The point variant finds 22 of 22 and runs in ~2ms instead of
      # into the statement timeout (ST_Buffer over a federal-state multipolygon is too expensive).
      def geo_region_concept_ids
        return @geo_region_concept_ids if defined?(@geo_region_concept_ids)
        return @geo_region_concept_ids = [] if geo_region_scheme_ids.blank? || anchor_polygon_ids.blank?

        @geo_region_concept_ids = DataCycleCore::ConceptPolygon
          .where(concept_id: geo_region_candidate_ids)
          .where(
            'EXISTS (SELECT 1 FROM concept_polygons anchor WHERE anchor.id IN (?) ' \
            'AND ST_Covers(anchor.geom, ST_PointOnSurface(COALESCE(concept_polygons.geom_simple, concept_polygons.geom))))',
            anchor_polygon_ids
          )
          .distinct
          .pluck(:concept_id)
      end

      def geo_region_candidate_ids
        self.class.concepts_in_schemes(geo_region_scheme_ids).reorder(nil).select(:id)
      end

      def anchor_polygon_ids
        @anchor_polygon_ids ||= DataCycleCore::ConceptPolygon.where(concept_id: anchor.id).pluck(:id)
      end

      def geo_region_scheme_ids
        @geo_region_scheme_ids ||= DataCycleCore::ConceptScheme
          .where(name: DataCycleCore::Feature::Mcp.geo_region_trees)
          .pluck(:id)
      end

      # Place names of the resolved subtree, stripped of the administrative prefixes ("Gemeinde Egg"
      # -> "Egg"), because address_locality carries the bare place name.
      def localities
        # reorder(nil): the default_scope of Concept sorts by order_a/id, which raises an
        # InvalidColumnReference in PG together with DISTINCT on a single column.
        @localities ||= DataCycleCore::Concept
          .where(id: subtree_concept_ids)
          .where.not(internal_name: nil)
          .reorder(nil)
          .distinct
          .pluck(:internal_name)
          .map { |name| strip_locality_prefix(name) }
          .uniq
      end

      # Without configured prefixes the name stays unchanged; the shipped list is the German one of
      # "Administrative Einheiten" (see Feature::Mcp.locality_prefix_pattern).
      def strip_locality_prefix(name)
        pattern = DataCycleCore::Feature::Mcp.locality_prefix_pattern

        pattern ? name.sub(pattern, '') : name
      end

      # Complements the name comparison, because in practice address_locality carries LOCALITIES
      # and name variants that do not exist as a concept in the administrative tree
      # (Riezlern/Hirschegg -> Gemeinde Mittelberg, "Lech am Arlberg" vs. "Lech"), and because the
      # tree itself can be incomplete (79 of 96 Vorarlberg municipalities). Without postal codes the
      # cascade loses 570 of its 5926 hits (LodgingBusiness, measured 2026-07-31) -- the largest
      # items are 6791 Sankt Gallenkirch and 6991/6992 Kleinwalsertal.
      #
      # Deliberately config and not code, so the assumption stays visible and maintainable:
      # postal-code spaces are instance-specific, so the gem ships the patterns empty. The filter
      # knows only the postal code, not the country -- four-digit neighbouring codes (NL/CH) lie in
      # the same number range and fall in with them. In vcloud-dev that is 6 contents against 570
      # correct ones; with a relevant foreign inventory this stage would need a country condition
      # rather than a narrower pattern.
      def postal_code_pattern
        @postal_code_pattern ||= DataCycleCore::Feature::Mcp.postal_code_patterns[anchor.internal_name]
      end

      def quote(value)
        ActiveRecord::Base.connection.quote(value)
      end

      def quote_list(values)
        values.map { |v| quote(v) }.join(',')
      end
    end
  end
end
