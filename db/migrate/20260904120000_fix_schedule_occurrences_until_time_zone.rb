# frozen_string_literal: true

# Reinstalls generate_schedule_occurences, which reads an rrule's UTC UNTIL as UTC from here on.
#
# The definition is built from Schedule.schedule_occurrences_sql rather than inlined, because
# rebuild_occurrences writes the same statement at runtime and the two drifting apart is what let
# this bug survive a rewrite of the function.
class FixScheduleOccurrencesUntilTimeZone < ActiveRecord::Migration[8.0]
  def up
    execute('SET LOCAL statement_timeout = 0;')
    execute(DataCycleCore::Schedule.schedule_occurrences_sql(**DataCycleCore::Schedule.occurrences_range))
  end

  def down
  end
end
