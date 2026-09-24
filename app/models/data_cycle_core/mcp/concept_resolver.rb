# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Maps ONE user term onto ALL concepts that can stand for it and returns a ready-made,
    # OR-combined group for search_contents' classification_alias_id_groups.
    #
    # The reason is a measured class of error, not convenience: in imported inventories the same
    # fact exists as several concepts with different UUIDs ("Vegan" 17, "Vegane Kost" 25, "Vegane
    # Speisen" 42, "Vegane Kost" 0 -- union 81). Until now the tool description merely urged the
    # client to collect all the variants itself; whoever took the first name match reported 17
    # instead of 81 and saw nothing of it -- a plausible number, not recognisable as wrong. This
    # class turns that into code: the union is formed and its hit count is put beside the strongest
    # single variant.
    class ConceptResolver
      DEFAULT_LIMIT = 25

      # An empty group is the most dangerous answer this tool can give: passed to search_contents it
      # filters NOTHING, the request returns the endpoint's total, and that looks like a result.
      # Measured: "barrierefrei" matches 8 identically named concepts, all empty in this endpoint ->
      # group [], and a count over the empty group would have reported 19,831, i.e. "19,831
      # barrier-free businesses". In that case NO count is delivered on purpose, but this warning
      # instead -- a missing number is recognisable as a problem, a wrong one is not.
      #
      # Localized and therefore a method rather than a constant: the text goes to the client and, as
      # a German literal, was the only part of this response that did not follow the mount's
      # language.
      # @param locale [Symbol] defaults to the language of the running tool call (Tools::Base sets
      #   it, see there).
      def self.empty_group_warning(locale: I18n.locale)
        DataCycleCore::Mcp::Translations.t('concept_resolver.empty_group_warning', locale:)
      end

      # @param base_query [Filter::Search] the query scoped to the endpoint (for the counts)
      # @param concept_schemes [Enumerable<ConceptScheme>] the schemes being searched
      def initialize(base_query:, concept_schemes:)
        @base_query = base_query
        @concept_schemes = concept_schemes.to_a
        @scheme_names = @concept_schemes.to_h { |s| [s.id, s.name] }
        @warnings = []
      end

      # Notices from the last #call, for the envelope's warnings -- see Tools::Base#warnings. Here
      # and not in the returned hash, because an empty group is a statement about the CALL ("the
      # number you would compute from this is not the one you want"), not a field of its result.
      attr_reader :warnings

      # @param term [String] the user's term, e.g. "vegan"
      # @param include_empty [Boolean] also take variants without contents into the group
      def call(term:, include_empty: false, limit: DEFAULT_LIMIT)
        variants = variants_for(term, limit)
        selected, redundant = split_redundant(variants.reject { |v| !include_empty && v[:thing_count_with_subtree].zero? })
        ids = selected.pluck(:id)
        @warnings = ids.blank? ? [self.class.empty_group_warning] : []

        {
          term: term,
          searched_concept_schemes: @concept_schemes.map { |s| { id: s.id, name: s.name } },
          concepts: variants.map { |v| annotate(v, ids, redundant) },
          classification_alias_id_group: ids,
          count: union_count(ids),
          largest_single_variant_count: variants.pluck(:thing_count_with_subtree).max.to_i
        }.compact
      end

      # The real hit count of the union -- not the sum of the individual counts: a content can carry
      # several variants (in the vegan example the three populated ones overlap), so the sum counts
      # it more than once and would be too high, while the strongest single variant is too low.
      #
      # nil on an empty group, NOT the endpoint total (see .empty_group_warning): the return value
      # is read as "this many contents carry this term", and for that the total is not merely
      # imprecise but the exact opposite of the truth.
      def union_count(ids)
        return nil if ids.blank?

        @base_query.concept_ids_with_subtree(ids).count
      end

      private

      def variants_for(term, limit)
        return [] if term.blank?

        matches = concepts_in_schemes
          .where(
            '(concepts.name_i18n ->> :locale) ILIKE :q OR concepts.internal_name ILIKE :q',
            locale: I18n.locale.to_s, q: "%#{ilike_pattern(term)}%"
          )
          .limit(limit.to_i.clamp(1, 200))
          .to_a

        with_counts(matches).sort_by { |v| -v[:thing_count_with_subtree] }
      end

      # The term comes from an LLM and is placed into an ILIKE pattern. Substring matching is wanted
      # here, UNLIKE in GeoScope#anchor_in (it is what collects the name variants) -- the user term's
      # wildcards are not: term "%" matched every concept of the endpoint and returned a group with
      # a plausible union count nobody had asked for.
      # Escape first, then turn the gaps between words into wildcards (multi-word terms should still
      # match across intervening words).
      def ilike_pattern(term)
        term.to_s.squish.gsub(/[\\%_]/) { |char| "\\#{char}" }.gsub(/\s/, '%')
      end

      # Only the concept's own name is compared, not its full_path as in Concept.search: through the
      # path every child of a matching node matches too ("Vegan > Frühstück"), which fills the group
      # with concepts the term does not mean and makes the response list unreadable.
      def concepts_in_schemes
        DataCycleCore::Concept.where(concept_scheme_id: @concept_schemes.map(&:id))
      end

      # Counts per scheme, because thing_counts_for_tree counts per scheme. Endpoint-scoped (unlike
      # list_concepts, which counts instance-wide): a variant that is populated instance-wide can be
      # empty in this endpoint, and then it does not belong in the group.
      def with_counts(concepts)
        concepts.group_by(&:concept_scheme_id).flat_map do |concept_scheme_id, scheme_concepts|
          counts = DataCycleCore::Concept
            .thing_counts_for_tree(concept_scheme_id:, query: @base_query.query, min_count_with_subtree: 0)
            .where(id: scheme_concepts.map(&:id))
            .to_h { |c| [c.id, c.thing_count_with_subtree] }

          scheme_concepts.map do |concept|
            {
              id: concept.id,
              name: concept.name,
              concept_scheme_id:,
              concept_scheme: @scheme_names[concept_scheme_id],
              thing_count_with_subtree: counts[concept.id].to_i
            }
          end
        end
      end

      # A concept whose ancestor is in the group as well is redundant: the filter pulls the subtree
      # in anyway. Leaving it in would not be wrong, but the group is meant to document the
      # decision -- a list with parents AND children reads as two conditions where only one is
      # meant.
      def split_redundant(variants)
        ids = variants.pluck(:id)
        ancestors = DataCycleCore::ConceptPath
          .where(id: ids)
          .to_h { |p| [p.id, p.full_path_ids.to_a - [p.id]] }

        variants.partition { |v| !ancestors[v[:id]].to_a.intersect?(ids) }
      end

      def annotate(variant, selected_ids, redundant)
        variant.merge(
          in_group: selected_ids.include?(variant[:id]),
          excluded_reason: group_exclusion_reason(variant, selected_ids, redundant)
        ).compact
      end

      # Localized like every other client-visible text of this server: the two reasons used to sit
      # as English literals beside a German warning in the same response.
      def group_exclusion_reason(variant, selected_ids, redundant)
        return nil if selected_ids.include?(variant[:id])
        return DataCycleCore::Mcp::Translations.t('concept_resolver.excluded.redundant') if redundant.any? { |r| r[:id] == variant[:id] }

        DataCycleCore::Mcp::Translations.t('concept_resolver.excluded.empty')
      end
    end
  end
end
