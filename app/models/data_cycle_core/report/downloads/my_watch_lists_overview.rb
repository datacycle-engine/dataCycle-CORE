# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      # Generates a downloadable report of all watch lists accessible to the current user.
      # Excludes the user's personal selection ("My Selection") and includes direct URLs
      # to each watch list.
      class MyWatchListsOverview < Base
        # Retrieves accessible watch lists with name, ID, and URL.
        def apply(_params)
          raw_query = <<~SQL.squish
            SELECT collections.name AS name,
              collections.id AS id,
              CONCAT(?, '/', collections.id) AS url
            FROM collections
            WHERE id IN (?)
            ORDER BY
              collections.name,
              collections.id;
          SQL

          shared_ids = DataCycleCore::WatchList.accessible_by(current_user.ability)
            .without_my_selection
            .pluck(:id)
          base_url = DataCycleCore::UrlService.instance.watch_lists_url

          @data = ActiveRecord::Base.connection.select_all(
            ActiveRecord::Base.send(:sanitize_sql_for_conditions, [raw_query, base_url, shared_ids])
          )
        end
      end
    end
  end
end
