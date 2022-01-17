# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      class Content < Base
        def apply(params)
          thing_id = params&.dig(:thing_id)
          date_time_format = 'DD.MM.YYYY HH24:MI:SS'
          raise DataCycleCore::Error::RecordNotFoundError "#{thing_id} not found!" if DataCycleCore::Thing.find(thing_id).blank?
          raw_query = <<-SQL.squish
            SELECT 
                "things"."id", 
                "thing_translations"."name", 
                to_char("activities"."created_at", :date_time_format) as date_created,
                "users"."email",
                concat("users"."given_name", ' ', "users"."family_name") as user_display_name
            FROM things
            JOIN thing_translations ON things.id = thing_translations.thing_id AND thing_translations.locale = :locale
            JOIN activities ON things.id = activities.activitiable_id 
            OR things.id = ANY (
              ARRAY(SELECT jsonb_array_elements_text(activities.data -> 'collection_items'))::uuid[]
            )
            JOIN users on activities.user_id = users.id
            where activities.activity_type = 'download'
            AND "things"."id" = :thing_id
            ORDER BY date_created DESC
          SQL

          @data = ActiveRecord::Base.connection.execute(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [raw_query, thing_id: thing_id, locale: @locale, date_time_format: date_time_format]))
        end
      end
    end
  end
end
