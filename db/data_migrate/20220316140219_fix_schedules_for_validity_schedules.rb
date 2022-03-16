# frozen_string_literal: true

class FixSchedulesForValiditySchedules < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE
        schedules
      SET
        rrule = REPLACE(rrule, 'BYYEARDAY=' || array_to_string(get_byyearday (rrule::rrule), ','),
          'BYYEARDAY=' || (get_byyearday (rrule::rrule))[1])
      WHERE
        array_length(get_byyearday (rrule::rrule), 1) > 1;
    SQL
  end

  def down
  end
end
