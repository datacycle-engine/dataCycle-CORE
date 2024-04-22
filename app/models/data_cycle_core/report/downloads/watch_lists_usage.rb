# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      class WatchListsUsage < Base
        def apply(_params)
          raw_query = <<-SQL.squish
            SELECT
              collections.name AS NAME,
              MIN(
                CONCAT(
                  users.given_name,
                  ' ',
                  users.family_name,
                  ' <',
                  users.email,
                  '>'
                )
              ) AS creator,
              collections.api AS api_access,
              MAX(activities.created_at) AS last_used_api,
              COUNT(activities.id) FILTER (
                WHERE
                  activities.created_at >= (DATE_TRUNC('week', NOW()))
              ) AS api_usage_current_week,
              COUNT(activities.id) FILTER (
                WHERE
                  activities.created_at >= (DATE_TRUNC('week', NOW()) - INTERVAL '1 week')
                  AND activities.created_at < DATE_TRUNC('week', NOW())
              ) AS api_usage_last_week,
              COUNT(activities.id) FILTER (
                WHERE
                  activities.created_at >= (DATE_TRUNC('month', NOW()))
              ) AS api_usage_current_month,
              COUNT(activities.id) FILTER (
                WHERE
                  activities.created_at >= (DATE_TRUNC('month', NOW()) - INTERVAL '1 month')
                  AND activities.created_at < DATE_TRUNC('month', NOW())
              ) AS api_usage_last_month,
              COUNT(activities.id) FILTER (
                WHERE
                  activities.created_at >= (DATE_TRUNC('month', NOW()) - INTERVAL '12 months')
                  AND activities.created_at < DATE_TRUNC('month', NOW())
              ) AS api_usage_last_12_months
            FROM
              collections
              LEFT OUTER JOIN users ON users.id = collections.user_id
              LEFT OUTER JOIN activities ON activities.data ->> 'id' = collections.id::TEXT
            GROUP BY
              collections.name,
              collections.id
            ORDER BY
              collections.name,
              collections.id;
          SQL

          @data = ActiveRecord::Base.connection.execute(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [raw_query]))
        end

        private

        def translated_headings
          by_month = @params&.dig(:by_month) || Time.zone.now.month
          by_year = @params&.dig(:by_year) || Time.zone.now.year
          by_month_string = DataCycleCore::MasterData::DataConverter.string_to_datetime([0o7, by_month, by_year].join('-'))
          @data.fields.map do |key|
            if key == 'downloads_by_month'
              I18n.t "feature.report_generator.headings.#{key}", default: key, date: I18n.l(by_month_string, format: '%B %Y'), locale: @locale
            else
              I18n.t "feature.report_generator.headings.#{key}", default: key, locale: @locale
            end
          end
        end
      end
    end
  end
end
