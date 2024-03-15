# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      class UserInfoActivity < Base
        def apply(_params)
          raw_query = <<-SQL.squish
            WITH latest_activity_timestamps AS (
              SELECT user_id, MAX(updated_at) AS latest_api_access
              FROM activities
              WHERE activity_type LIKE '%api_v%'
              GROUP BY user_id
            )
            SELECT u.id, u.given_name as first_name,  u.family_name as last_name, u.created_at, u.updated_at, u.last_sign_in_at, u.current_sign_in_at, u.sign_in_count, u.deleted_at, u.locked_at, u.external, u.ui_locale , roles.name AS role_name, ua.activity_type AS latest_activity_type, lat.latest_api_access
            FROM users u
            JOIN latest_activity_timestamps lat ON u.id = lat.user_id
            JOIN activities ua ON u.id = ua.user_id AND lat.latest_api_access = ua.updated_at
            JOIN roles ON u.role_id = roles.id;
          SQL

          @data = ActiveRecord::Base.connection.execute(ActiveRecord::Base.send(:sanitize_sql, raw_query))
        end
      end
    end
  end
end
