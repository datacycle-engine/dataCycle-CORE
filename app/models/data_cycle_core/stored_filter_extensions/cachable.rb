# frozen_string_literal: true

module DataCycleCore
  module StoredFilterExtensions
    module Cachable
      extend ActiveSupport::Concern

      # Grace window (minutes) added to `cache_ttl` when deciding whether a cache is still fresh.
      # It bridges the proactive rebuild (see the `with_stale_cache` scope, which marks caches stale
      # ~9 min before ttl) so requests keep serving the existing cache while the rebuild runs instead
      # of recomputing live. The SQL `resolve_stored_search` function applies the same window — keep
      # the two in sync (covered by a parity test).
      CACHE_VALIDITY_GRACE_MINUTES = 10

      included do
        has_many :stored_filter_caches, class_name: 'DataCycleCore::StoredFilterCache', inverse_of: :stored_filter, dependent: :delete_all

        scope :cachable, -> { where(cache_ttl: 1..) }
        scope :with_stale_cache, -> { cachable.where('cache_updated_at IS NULL OR cache_updated_at < (NOW() - ((cache_ttl - 9) * INTERVAL \'1 minute\'))') }

        validates :cache_ttl, numericality: { only_integer: true, in: 0..1440 }, allow_nil: true

        attr_accessor :cached_result

        after_save :rebuild_cache!, if: :saved_change_to_cache_ttl?
      end

      def cached(cached = true)
        self.cached_result = cached
        self
      end

      def rebuild_cache!
        remove_cache! && return unless cache_result?

        transaction do
          self.class.connection.exec_query('SET LOCAL statement_timeout = 600000;') # 10 minutes
          things_sql = cached(false).apply_nested.select(:id)
          sql = <<~SQL.squish
            WITH contents AS (#{things_sql.to_sql}),
            inserted_caches AS (
              INSERT INTO stored_filter_caches (stored_filter_id, thing_id)
              SELECT :sf_id,
                id
              FROM contents ON conflict (stored_filter_id, thing_id) DO nothing
            )
            DELETE FROM stored_filter_caches
            WHERE stored_filter_id = :sf_id
              AND thing_id NOT IN (
                SELECT id
                FROM contents
              );
          SQL

          sanitized_sql = ActiveRecord::Base.send(:sanitize_sql_array, [sql, { sf_id: id }])
          self.class.connection.exec_query(sanitized_sql)
          update_columns(cache_updated_at: Time.current)
        end
      end

      def remove_cache!
        stored_filter_caches.delete_all
        update_columns(cache_updated_at: nil)
      end

      def cache_result?
        !cache_ttl.nil? &&
          cache_ttl.positive?
      end

      # Cache is valid if it is enabled, has been updated at least once, the parameters have not changed,
      # and is not older than ttl + CACHE_VALIDITY_GRACE_MINUTES. The SQL `resolve_stored_search` applies
      # the identical window so the API (Ruby) and Grafana (SQL) never disagree around the TTL boundary.
      def cached_result?
        cache_result? &&
          cached_result &&
          !parameters_changed? &&
          cache_updated_at.present? &&
          cache_updated_at >= (cache_ttl + CACHE_VALIDITY_GRACE_MINUTES).minutes.ago
      end

      private

      def cached_query(locale: language)
        locale = Array.wrap(locale).presence
        locale = nil if locale&.include?('all')

        query = DataCycleCore::Thing.where(
          DataCycleCore::StoredFilterCache
            .where(stored_filter_id: id)
            .where('"stored_filter_caches"."thing_id" = "things"."id"')
            .select(1)
            .arel.exists
        )

        DataCycleCore::Filter::Search
          .new(locale:, include_embedded: include_embedded || false, query:)
          .with_locale(locale)
      end
    end
  end
end
