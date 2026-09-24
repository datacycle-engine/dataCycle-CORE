# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Fulltext
        extend ActiveSupport::Concern

        FULLTEXT_WEIGHT_MAP = { 'name' => 'A', 'dc:slug' => 'B', 'dc:classification' => 'C', 'dc:text' => 'D' }.freeze
        FULLTEXT_FIELDS = FULLTEXT_WEIGHT_MAP.keys.freeze
        FULLTEXT_WEIGHTS = FULLTEXT_WEIGHT_MAP.values.uniq.freeze

        def legacy_fulltext_search(value)
          value = value[:value] if value.is_a?(Hash)
          return self if value.blank?

          normalized_name = value.unicode_normalize(:nfkc)
          squished_name = normalized_name.squish
          locales = Array.wrap(@locale).compact_blank.uniq
          all_text = search[:all_text].matches_all(normalized_name.split.map { |item| "%#{item.strip}%" })
          subquery = DataCycleCore::Search.select(1)
          subquery = subquery.where(locale: locales) if locales.present?
          subquery = subquery.where(search[:content_data_id].eq(thing[:id]))
          subquery = if locales.present?
                       subquery.where(all_text.or(words_match(squished_name, locales)))
                     else
                       subquery
                         .left_outer_joins(:pg_dict_mapping)
                         .where(all_text.or(tsmatch(search[:words], tsquery(quoted(squished_name), pg_dict_mapping[:dict]))))
                     end

          reflect(@query.where(subquery.arel.exists))
        end

        def ts_query_fulltext_search(value)
          value, fields = value.values_at(:value, :fields) if value.is_a?(Hash)
          return self if value.blank?

          q = text_to_websearch_tsquery(value)
          weights = fulltext_fields_to_weights(fields)
          locales = Array.wrap(@locale).compact_blank.uniq
          subquery = DataCycleCore::Search.select(1)
          subquery = subquery.where(locale: locales) if locales.present?
          subquery = subquery.where(search[:content_data_id].eq(thing[:id]))
          subquery = if locales.present?
                       subquery.where(search_vector_prefix_match(q, weights, locales))
                     else
                       subquery
                         .left_outer_joins(:pg_dict_mapping)
                         .where(tsmatch(search[:search_vector], websearch_to_prefix_tsquery(q, pg_dict_mapping[:dict], weights)))
                     end

          reflect(@query.where(subquery.arel.exists))
        end

        class_methods do
          def fulltext_fields_to_weights(fields_string)
            return '' if fields_string.blank?

            weights = fields_string.split(',').filter_map { |f| FULLTEXT_WEIGHT_MAP[f.strip] }.uniq

            # an empty weight string already means "every weight"; spelling it out would only cost a heap recheck
            return '' if weights.size == FULLTEXT_WEIGHTS.size

            weights.join
          end
        end

        delegate :fulltext_fields_to_weights, to: :class

        # used to alias the fulltext search method based on feature flag without class reloading
        def self.alias_fulltext_search_method!
          if Feature::TsQueryFulltextSearch.enabled?
            alias_method :fulltext_search, :ts_query_fulltext_search
          else
            alias_method :fulltext_search, :legacy_fulltext_search
          end
        end

        alias_fulltext_search_method!

        private

        # Yields each locale's dictionary as an IMMUTABLE get_dict('de') call and ORs the
        # resulting predicates together. Both fulltext implementations build their tsquery
        # through here, and this block is where the reason for that lives.
        #
        # Because get_dict is IMMUTABLE, a tsquery built on it folds to a literal at plan time
        # and a GIN index can serve it as an index condition. Read from a joined
        # pg_dict_mappings column the tsquery is not constant, and the consequence differs per
        # implementation:
        #
        # - ts_query_fulltext_search matches one predicate, so the planner stays free to drive
        #   the loop from searches, where `@@` degrades to a filter over every row of the
        #   locale: 77 ms vs 14 ms for 'wandern berge' on 598k German rows.
        # - legacy_fulltext_search ORs `all_text ILIKE` with `words @@`, and a BitmapOr needs
        #   every branch indexable. The non-constant branch made the whole OR a filter and took
        #   all_text_idx down with it, so neither index was reachable and every search probed
        #   searches once per candidate thing: 'zwergfledermaus' took 1564 ms over 330,811 such
        #   probes, against 3.2 ms once the BitmapOr can use both indexes. Over 25 real stored
        #   filter search terms this was 22.5x geometric mean, 25 faster and none slower.
        #
        # The literal also hands the planner a selectivity estimate it did not have before,
        # which is why this is a trade and not a free win. Over 40 real fulltext stored filters
        # ts_query gained 2.7x geometric mean (34 faster, 3 slower); the 3 losses are queries
        # carrying a far more selective filter, such as an in_schedule window, where the
        # estimate tips the planner into starting from the GIN scan instead of rechecking the
        # predicate on the handful of rows that filter already produced -- 'advent' goes
        # 1.5 ms -> 8.9 ms. Legacy has a rarer but sharper version: a query whose terms are all
        # common ('wandern berge') makes the lossy trigram branch of the BitmapOr return 13,907
        # rows against an estimate of 322, and the heap recheck costs 21 ms -> 454 ms. No term
        # in the real sample above hit that, because real searches name places and events.
        #
        # Each locale keeps its own guard so a row is only ever matched against its own
        # dictionary, which is what reading the joined column gave us per row. A single locale
        # needs no guard: the surrounding subquery already restricts searches.locale to it.
        #
        # @param locales [Array<String>] the locales the surrounding subquery is restricted to
        # @yieldparam dict [Arel::Nodes::NamedFunction] that locale's get_dict call
        # @return [Arel::Nodes::Node] the per-locale predicates ORed together
        def per_locale_match(locales)
          single_locale = locales.one?

          locales.map { |locale|
            match = yield(get_dict(locale))

            single_locale ? match : search[:locale].eq(locale).and(match)
          }.reduce(:or)
        end

        # @param weights [String] tsquery weight labels such as 'AB', or '' for every weight
        def search_vector_prefix_match(query_string, weights, locales)
          per_locale_match(locales) do |dict|
            tsmatch(search[:search_vector], websearch_to_prefix_tsquery(query_string, dict, weights))
          end
        end

        def words_match(query_string, locales)
          per_locale_match(locales) do |dict|
            tsmatch(search[:words], tsquery(quoted(query_string), dict))
          end
        end
      end
    end
  end
end
