# frozen_string_literal: true

# Recomputes every schedule's occurrences columns against the corrected function.
#
# occurrences and occurrences_array are GENERATED ALWAYS ... STORED, so the CREATE OR REPLACE in
# 20260904120000 changes nothing that is already materialized - each row has to be written once for
# PostgreSQL to re-evaluate it, which is what the rebuild task does.
#
# That rewrite leaves a dead tuple per row: both generated columns are indexed, so no update is HOT.
# The table grew 28 MB -> 48 MB on this project's 5102 schedules. Autovacuum would free the space for
# reuse but neither return it to the OS nor undo the GIN index bloat, so the task follows up with a
# VACUUM FULL, which rewrites heap, TOAST and indexes compactly.
#
# It is requested separately for 19:00, the hour 20260430140246 already uses for this table, because
# VACUUM FULL holds ACCESS EXCLUSIVE for that whole rewrite while every other connection carries
# database.yml's statement_timeout of 1min - so a request touching schedules does not queue behind
# it, it errors after a minute. A deploy runs whenever it runs and cannot pick that moment.
class RebuildScheduleOccurencesAfterUntilTimeZoneFix < ActiveRecord::Migration[8.0]
  def up
    vacuum_at = Time.zone.now.change(hour: 19)
    vacuum_at += 1.day if vacuum_at.past? # a deploy after 19:00 would otherwise vacuum immediately

    DataCycleCore::RunTaskJob.perform_later('db:configure:rebuild_schedule_occurrences', [false])
    DataCycleCore::RunTaskJob
      .set(wait_until: vacuum_at, queue: 'importers')
      .perform_later('db:maintenance:vacuum', [true, 'schedules'])
  end

  def down
  end
end
