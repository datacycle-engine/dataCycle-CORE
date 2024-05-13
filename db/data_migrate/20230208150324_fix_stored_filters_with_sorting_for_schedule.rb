# frozen_string_literal: true

class FixStoredFiltersWithSortingForSchedule < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    return unless ActiveRecord::Base.connection.table_exists? 'stored_filters'
    execute <<-SQL.squish
      UPDATE stored_filters
      SET sort_parameters = jsonb_set(
          sort_parameters,
          '{0,v}',
          jsonb_build_object(
            'v',
            (sort_parameters#>'{0,v}'),
            'q',
            CASE
              WHEN sort_parameters#>'{0,v,from,n}' IS NULL THEN 'absolute'
              ELSE 'relative'
            END
          ),
          false
        )
      WHERE sort_parameters::text ilike '%"m": "by_proximity"%'
        AND sort_parameters#>'{0,v,v}' IS NULL;
    SQL
  end

  def down
  end
end
