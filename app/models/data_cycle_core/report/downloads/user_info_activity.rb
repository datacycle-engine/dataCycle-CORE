# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      class UserInfoActivity < Base
        def apply(params)
          raw_query = <<-SQL.squish
            WITH latest_activity_timestamps AS (
              SELECT user_id, MAX(updated_at) AS latest_api_access
              FROM activities
              WHERE activity_type LIKE '%api_v%'
              GROUP BY user_id
            ),
            user_groups_agg AS (
              SELECT ugu.user_id, string_agg(ug.name, ', ') AS user_group_names
              FROM user_group_users ugu
              JOIN user_groups ug ON ugu.user_group_id = ug.id
              GROUP BY ugu.user_id
            )
            SELECT u.id, u.given_name as first_name,  u.family_name as last_name, u.email, uga.user_group_names, u.created_at, u.updated_at, u.last_sign_in_at, u.current_sign_in_at, u.sign_in_count, u.deleted_at, u.locked_at, u.external, u.ui_locale, lat.latest_api_access, ua.activity_type AS latest_activity_type
            FROM users u
            LEFT JOIN latest_activity_timestamps lat ON u.id = lat.user_id
            LEFT JOIN activities ua ON u.id = ua.user_id AND lat.latest_api_access = ua.updated_at
            LEFT JOIN user_groups_agg uga ON u.id = uga.user_id
            WHERE u.id IN (\'#{params[:user_ids].join("', '")}\');
          SQL

          @data = ActiveRecord::Base.connection.execute(ActiveRecord::Base.send(:sanitize_sql, raw_query))
        end
      end
    end
  end
end
