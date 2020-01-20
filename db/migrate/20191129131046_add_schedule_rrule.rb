# frozen_string_literal: true

class AddScheduleRrule < ActiveRecord::Migration[5.2]
  def change
    # https://github.com/petropavel13/pg_rrule
    enable_extension 'pg_rrule' unless extension_enabled?('pg_rrule')

    create_table :schedules, id: :uuid do |t|
      t.uuid      :thing_id                                                     # thing_id
      t.string    :relation                                                     # relation_name
      t.column    :dtstart, 'timestamp with time zone'                          # start_date_time
      t.column    :dtend, 'timestamp with time zone'                            # end_data_time optional
      t.interval  :duration                                                     # duration of event
      t.string    :rrule                                                        # String representation of rrule -> https://icalendar.org/RFC-Specifications/iCalendar-RFC-5545/
      t.column    :rdate, 'timestamp with time zone', array: true, default: []  # array of event_date_times (additionally to rrule occurrences)
      t.column    :exdate, 'timestamp with time zone', array: true, default: [] # array of exception_data_times
      t.uuid      :external_source_id
      t.string    :external_key
      t.datetime  :seen_at
      t.timestamps
    end

    create_table :schedule_histories, id: :uuid do |t|
      t.uuid      :thing_history_id                                             # thing_history_id
      t.string    :relation                                                     # relation_name
      t.column    :dtstart, 'timestamp with time zone'                          # start_date_time
      t.column    :dtend, 'timestamp with time zone'                            # end_data_time optional
      t.interval  :duration                                                     # duration of event
      t.string    :rrule                                                        # String representation of rrule -> https://icalendar.org/RFC-Specifications/iCalendar-RFC-5545/
      t.column    :rdate, 'timestamp with time zone', array: true, default: []  # array of event_date_times (additionally to rrule occurrences)
      t.column    :exdate, 'timestamp with time zone', array: true, default: [] # array of exception_data_times
      t.uuid      :external_source_id
      t.string    :external_key
      t.datetime  :seen_at
      t.timestamps
    end
  end
end
