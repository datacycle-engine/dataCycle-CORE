# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      class WidgetUsage < Base
        def apply(_params)
          raw_query = <<-SQL.squish
            WITH raw_report_data AS (
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
                            AND (data->'page'->>'number' = '1' OR data->'page' IS NULL) THEN 1
                        ELSE 0
                    END AS true_count,
                  CASE
                        WHEN data->>'action' IN ('index', 'show')
                            AND (data->'page'->>'number' IS NOT NULL AND CAST(data->'page'->>'number' AS INTEGER) > 1) THEN 1
                        ELSE 0
                    END AS retention_count,
                  data
                FROM activities
                WHERE data->>'middlewareOrigin' IS NOT NULL
            )
            SELECT url AS "url",
                COUNT(*) AS "access_count",
                SUM(true_count) AS "true_count",
                SUM(retention_count) AS "retention_count",
                SUM(true_count) + SUM(retention_count) AS "combined_count",
                CONCAT(
                    TO_CHAR(created_at, 'IYYY'),
                    '-W',
                    TO_CHAR(created_at, 'IW')
                ) AS "week"
            FROM raw_report_data
            GROUP BY url,
                CONCAT(
                    TO_CHAR(created_at, 'IYYY'),
                    '-W',
                    TO_CHAR(created_at, 'IW')
                )
            ORDER BY week DESC,
                access_count DESC;
          SQL

          # no need to sanitize the query as it is a constant string
          @data = ActiveRecord::Base.connection.select_all(raw_query)
        end
      end
    end
  end
end
