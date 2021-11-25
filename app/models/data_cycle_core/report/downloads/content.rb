# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      class Content < Base
        def apply(params)
          limit = params&.dig(:limit) || 50
          by_month = params&.dig(:by_month) || Time.zone.now.month
          raw_query = <<-SQL.squish
          SELECT 
            "things"."id", 
            "thing_translations"."name", 
            "activities"."activity_type", 
            count("things"."id") as downloads_all, 
            sum(1) FILTER (where EXTRACT(MONTH FROM "activities"."created_at") = :by_month) AS downloads_by_month
          FROM things
          JOIN thing_translations ON things.id = thing_translations.thing_id
          JOIN activities ON things.id = activities.activitiable_id 
          OR things.id = ANY (
              ARRAY(SELECT jsonb_array_elements_text(activities.data -> 'collection_items'))::uuid[]
          )
          where activities.activity_type = 'download'
          group by "things"."id", "thing_translations"."name", "activities"."activity_type"
          order by downloads_by_month DESC NULLS LAST, downloads_all DESC NULLS LAST
          LIMIT :limit
          SQL

          @data = ActiveRecord::Base.connection.execute(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [raw_query, by_month: by_month, limit: limit])).to_a
        end
      end
    end
  end
end
