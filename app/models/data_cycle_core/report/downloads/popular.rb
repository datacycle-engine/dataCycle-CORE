# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      class Popular < Base
        def apply(params)
          limit = params&.dig(:limit) || 50
          by_month = params&.dig(:by_month) || Time.zone.now.month
          by_year = params&.dig(:by_year) || Time.zone.now.year
          raw_query = <<-SQL.squish
            SELECT "things"."id",
              "thing_translations"."content"->>'name' AS "name",
              COUNT("things"."id") AS downloads_all,
              sum(1) FILTER (
                WHERE EXTRACT(
                    MONTH
                    FROM "activities"."created_at"
                  ) = :by_month
                  AND EXTRACT(
                    YEAR
                    FROM "activities"."created_at"
                  ) = :by_year
              ) AS downloads_by_month
            FROM things
              JOIN thing_translations ON things.id = thing_translations.thing_id
              AND thing_translations.locale = :locale
              JOIN activities ON things.id = activities.activitiable_id
              OR things.id = ANY (
                ARRAY(
                  SELECT jsonb_array_elements_text(activities.data->'collection_items')
                )::uuid []
              )
            WHERE activities.activity_type = 'download'
            GROUP BY "things"."id",
              "thing_translations"."content"->>'name'
            ORDER BY downloads_by_month DESC NULLS LAST,
              downloads_all DESC NULLS LAST
            LIMIT :limit
          SQL

          @data = ActiveRecord::Base.connection.execute(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [raw_query, by_month:, by_year:, locale: @locale, limit:]))
        end

        private

        def translated_headings
          by_month = @params&.dig(:by_month) || Time.zone.now.month
          by_year = @params&.dig(:by_year) || Time.zone.now.year
          by_month_string = DataCycleCore::MasterData::DataConverter.string_to_datetime([0o7, by_month, by_year].join('-'))
          @data.fields.map do |key|
            if key == 'downloads_by_month'
              I18n.t "feature.report_generator.headings.#{key}", default: key, date: I18n.localize(by_month_string, format: '%B %Y'), locale: @locale
            else
              I18n.t "feature.report_generator.headings.#{key}", default: key, locale: @locale
            end
          end
        end
      end
    end
  end
end
