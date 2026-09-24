# frozen_string_literal: true

module DataCycleCore
  module Feature
    class TsQueryFulltextSearch < Base
      SORT_ALGORITHM = 'ts_rank_cd'
      # get_dict(:locale) rather than a joined pg_dict_mappings.dict, so the tsquery is built
      # once per query instead of per candidate row -- see
      # Filter::Common::Fulltext#search_vector_prefix_match for why that matters.
      SORT_BASE = 'searches.search_vector, websearch_to_prefix_tsquery(get_dict(:locale), :q, :weights)'

      # The only two indexes on searches that Filter::Common::Fulltext#legacy_fulltext_search
      # can use and #ts_query_fulltext_search cannot: all_text_idx serves the legacy
      # `all_text ILIKE '%wandern%'`, index_searches_on_words its
      # `words @@ plainto_tsquery('german', ...)`. The ts_query implementation matches
      # searches.search_vector, which searches_search_vector_idx covers instead.
      #
      # Legacy only reaches them as one BitmapOr over both, which needs every branch of its OR
      # indexable -- so this list is worth restoring only while #legacy_fulltext_search names
      # the dictionary inline via per_locale_match. Take that away and both indexes go back to
      # being unreachable in either implementation, and restoring them buys nothing.
      #
      # The other trigram indexes on searches are deliberately absent here. headline_idx stays
      # either way, because Filter::Common::Typeahead issues `headline ILIKE ?`. words_idx
      # (on full_text) and classification_string_idx reach no query at all in either
      # implementation: their columns only appear inside similarity() in an ORDER BY, which GIN
      # cannot serve, so dropping those is not a question of this flag.
      LEGACY_ONLY_INDEXES = {
        'all_text_idx' => 'USING gin (all_text gin_trgm_ops)',
        'index_searches_on_words' => 'USING gin (words)'
      }.freeze

      class << self
        def sort_config
          Array.wrap(configuration[:sorting]).compact_blank
        end

        def sorting_string
          sorting_array = []

          sort_config.each do |config|
            sorting = [SORT_BASE]
            sorting.unshift("'#{config[:weights].to_pg_array}'") if config[:weights].present?
            sorting << config[:normalization] if config[:normalization].present?
            sorting_array << "ts_rank_cd(#{sorting.join(', ')})"
          end

          sorting_array.join(' + ')
        end

        # Drops LEGACY_ONLY_INDEXES while this feature is enabled and restores them while it is
        # not, so flipping the flag never leaves the implementation that actually runs without
        # its indexes. Idempotent in both directions, and reports only what it changed.
        #
        # On a 612k row searches table the two hold 409 MB (278 + 131) of its 1,115 MB of
        # index and cost their share of every write for nothing; rebuilding both takes ~50 s.
        #
        # Driven by db/seeds.rb and dc:features:sync_fulltext_indexes rather than a migration,
        # because which implementation runs is per-installation config: a migration branching on
        # the flag would make the committed db/structure.sql depend on the flag of whichever
        # machine dumped it. A fresh install therefore carries both indexes whether it ran the
        # migrations or loaded that structure.sql, and the seed is what reconciles it; run the
        # task after flipping the flag on an installation that is already set up.
        #
        # @return [Hash{String => Symbol}] index name => :dropped or :created
        def reconcile_legacy_indexes!
          connection = ActiveRecord::Base.connection
          return {} unless connection.table_exists?('searches')

          drop = enabled?
          # database.yml sets statement_timeout as a session variable, so RESET would restore
          # the server default (unlimited) rather than the configured 1min.
          previous_timeout = connection.select_value('SHOW statement_timeout')
          connection.execute('SET statement_timeout = 0;')
          dropped_invalid = drop_invalid_legacy_indexes!(connection)
          present = connection.indexes(:searches).map(&:name) - dropped_invalid

          LEGACY_ONLY_INDEXES.filter_map { |name, definition|
            quoted_name = connection.quote_table_name(name)

            if drop
              next if present.exclude?(name)

              connection.execute("DROP INDEX CONCURRENTLY IF EXISTS #{quoted_name};")
              [name, :dropped]
            else
              next if present.include?(name)

              connection.execute("CREATE INDEX CONCURRENTLY IF NOT EXISTS #{quoted_name} ON searches #{definition};")
              [name, :created]
            end
          }.to_h
        ensure
          connection&.execute("SET statement_timeout = #{connection.quote(previous_timeout)};") if previous_timeout
        end

        # An interrupted CREATE INDEX CONCURRENTLY leaves the index behind marked invalid: the
        # planner ignores it, every write still maintains it, and CREATE INDEX ... IF NOT
        # EXISTS matches it by name and so would never rebuild it. Clearing those first is what
        # makes reconcile_legacy_indexes! idempotent after a failed run.
        #
        # @return [Array<String>] the names dropped, so the caller counts them as absent
        def drop_invalid_legacy_indexes!(connection)
          names = connection.select_values(<<~SQL.squish)
            SELECT pg_class.relname FROM pg_class
            JOIN pg_index ON pg_index.indexrelid = pg_class.oid
            WHERE NOT pg_index.indisvalid
              AND pg_class.relname IN (#{LEGACY_ONLY_INDEXES.keys.map { |n| connection.quote(n) }.join(', ')})
          SQL

          names.each { |name| connection.execute("DROP INDEX CONCURRENTLY IF EXISTS #{connection.quote_table_name(name)};") }
        end

        # needed for tests
        def reload
          super

          DataCycleCore::Filter::Common::Fulltext.alias_fulltext_search_method!
          DataCycleCore::Filter::Sortable.alias_fulltext_search_method!
        end
      end
    end
  end
end
