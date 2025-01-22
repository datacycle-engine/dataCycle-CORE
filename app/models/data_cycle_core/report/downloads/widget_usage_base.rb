# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      module WidgetUsageBase
        def self.raw_report_data_sql
          <<-SQL.squish
            SELECT SUBSTRING(
                    data->>'middlewareOrigin',
                    0,
                    COALESCE(
                        NULLIF(POSITION('?' IN data->>'middlewareOrigin'), 0),
                        NULLIF(POSITION('#' IN data->>'middlewareOrigin'), 0),
                        1000000
                    )
                ) AS url,
                created_at,
                CASE
                    WHEN data->>'action' IN ('index', 'show')
                    AND (
                        data->'page'->>'number' = '1'
                        OR data->'page' IS NULL
                    ) THEN 1
                    ELSE 0
                END AS true_count,
                CASE
                    WHEN data->>'action' IN ('index', 'show')
                    AND (
                        data->'page'->>'number' IS NOT NULL
                        AND CAST(data->'page'->>'number' AS INTEGER) > 1
                    ) THEN 1
                    ELSE 0
                END AS retention_count,
                COALESCE(data->>'widgetType', 'unknown') AS widget_type,
                COALESCE(data->>'widgetVersion', 'unknown') AS widget_version,
                COALESCE(
                    (
                        SELECT (
                                regexp_matches(
                                    data->>'middlewareOrigin',
                                    '^(?:https?://)?([^/]+)'
                                )
                            ) [1]
                    ),
                    'unknown'
                ) AS domain
            FROM activities
            WHERE data->>'middlewareOrigin' IS NOT NULL
          SQL
        end

        def self.overview_sql
          <<-SQL.squish
                overview_data AS (
                    SELECT 'OVERVIEW' AS domain,
                        NULL AS url,
                        '0' AS sort_key,
                        0 AS sort_key_2,
                        week,
                        widget_type,
                        SUM(access_count) AS access_count,
                        SUM(true_count) AS true_count,
                        SUM(retention_count) AS retention_count,
                        SUM(combined_count) AS combined_count,
                        COUNT(DISTINCT domain) AS unique_domains
                    FROM aggregated_data
                    GROUP BY week,
                        widget_type
                    UNION ALL
                    SELECT 'OVERVIEW' AS domain,
                        NULL AS url,
                        '0' AS sort_key,
                        0 AS sort_key_2,
                        week,
                        'all' AS widget_type,
                        SUM(access_count) AS access_count,
                        SUM(true_count) AS true_count,
                        SUM(retention_count) AS retention_count,
                        SUM(combined_count) AS combined_count,
                        COUNT(DISTINCT domain) AS unique_domains
                    FROM aggregated_data
                    GROUP BY week
                ),
                overview_data_domains AS (
                    SELECT domain,
                        CONCAT('OVERVIEW: ', domain) AS sort_key,
                        0 AS sort_key_2,
                        NULL AS url,
                        week,
                        widget_type,
                        SUM(access_count) AS access_count,
                        SUM(true_count) AS true_count,
                        SUM(retention_count) AS retention_count,
                        SUM(combined_count) AS combined_count,
                        0 AS unique_domains
                    FROM aggregated_data
                    GROUP BY week,
                        domain,
                        widget_type
                    UNION ALL
                    SELECT domain,
                        CONCAT('OVERVIEW: ', domain) AS sort_key,
                        0 AS sort_key_2,
                        NULL AS url,
                        week,
                        'all' AS widget_type,
                        SUM(access_count) AS access_count,
                        SUM(true_count) AS true_count,
                        SUM(retention_count) AS retention_count,
                        SUM(combined_count) AS combined_count,
                        0 AS unique_domains
                    FROM aggregated_data
                    GROUP BY week,
                        domain
                ),
          SQL
        end

        def self.data_sql(is_overview:)
          if is_overview
            <<-SQL.squish
                SELECT week,
                    domain,
                    sort_key,
                    sort_key_2,
                    url,
                    widget_type,
                    access_count,
                    true_count,
                    retention_count,
                    combined_count,
                    unique_domains
                FROM overview_data
                UNION ALL
                SELECT week,
                    domain,
                    sort_key,
                    sort_key_2,
                    url,
                    widget_type,
                    access_count,
                    true_count,
                    retention_count,
                    combined_count,
                    unique_domains
                FROM overview_data_domains
            SQL
          else
            <<-SQL.squish
                SELECT week,
                    domain,
                    sort_key,
                    sort_key_2,
                    url,
                    widget_type,
                    access_count,
                    true_count,
                    retention_count,
                    combined_count,
                    0 AS unique_domains
                FROM aggregated_data
            SQL
          end
        end

        def self.base_query(is_overview:)
          data_sql = data_sql(is_overview:)
          overview_sql = is_overview ? overview_sql() : ''

          <<-SQL.squish
            WITH raw_report_data AS (
                #{raw_report_data_sql}
            ),
            aggregated_data AS (
                SELECT domain,
                    url,
                    CONCAT('OVERVIEW: ', domain) AS sort_key,
                    1 AS sort_key_2,
                    CONCAT(
                        TO_CHAR(created_at, 'IYYY'),
                        '-W',
                        TO_CHAR(created_at, 'IW')
                    ) AS week,
                    widget_type,
                    COUNT(*) AS access_count,
                    SUM(true_count) AS true_count,
                    SUM(retention_count) AS retention_count,
                    SUM(true_count) + SUM(retention_count) AS combined_count
                FROM raw_report_data
                GROUP BY domain,
                    url,
                    week,
                    widget_type
            ),
            #{overview_sql}
            data AS (
                #{data_sql}
            )
            SELECT week,
                domain,
                url,
                widget_type,
                access_count,
                true_count,
                retention_count,
                combined_count,
                NULLIF(unique_domains, 0) AS unique_domains
            FROM data
            ORDER BY week DESC,
                sort_key,
                sort_key_2,
                widget_type,
                access_count DESC;
          SQL
        end
      end
    end
  end
end
