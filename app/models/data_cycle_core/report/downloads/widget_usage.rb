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
                    ) url,
                    created_at
                FROM activities
                WHERE data->>'middlewareOrigin' IS NOT NULL
            )
            SELECT url AS "url",
                COUNT(*) AS "access_count",
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
            ORDER BY 3 DESC,
                2 DESC;
          SQL

          # no need to sanitize the query as it is a constant string
          @data = ActiveRecord::Base.connection.select_all(raw_query)
        end
      end
    end
  end
end
