# frozen_string_literal: true

class FixSchedulesUntilTime < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE schedules
      SET rrule = REGEXP_REPLACE(
          schedules.rrule,
          '(UNTIL=[0-9]*T)[0-9]*(Z;)',
          CASE
            WHEN substring(schedules.rrule, 'BYHOUR=([0-9]*);') IS NULL THEN '\\1235959\\2'
            ELSE concat(
              '\\1',
              LPAD(
                substring(schedules.rrule, 'BYHOUR=([0-9]*);'),
                2,
                '0'
              ),
              LPAD(
                coalesce(
                  substring(schedules.rrule, 'BYMINUTE=([0-9]*);'),
                  '00'
                ),
                2,
                '0'
              ),
              '00',
              '\\2'
            )
          END
        )
      WHERE schedules.rrule IS NOT NULL;
    SQL
  end

  def down
  end
end
