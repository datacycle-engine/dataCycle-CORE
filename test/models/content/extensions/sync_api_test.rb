# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SyncApiTest < ActiveSupport::TestCase
    def create_event
      DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: { name: 'Test Event' })
    end

    def update_event(event, data_hash)
      event.set_data_hash(data_hash: data_hash, partial_update: true, prevent_history: true)
      event
    end

    def create_event_with_overlay
      item = create_event
      update_event(item, {
        description: 'Test description',
        overlay: [{ name: 'Test Overlay' }]
      })
    end

    def create_event_with_classifications
      item = create_event
      update_event(item, { event_status: [DataCycleCore::Classification.find_by(name: 'Veranstaltung geplant').id] })
    end

    def create_event_with_overlay_classifications
      item = create_event
      update_event(item, {
        event_status: [DataCycleCore::Classification.find_by(name: 'Veranstaltung geplant').id],
        overlay: [{ name: 'Test Overlay', event_status: [DataCycleCore::Classification.find_by(name: 'Veranstaltung abgesagt').id] }]
      })
    end

    def event_date_range(month)
      { start_date: Time.new(2020, month, 1).in_time_zone, end_date: Time.new(2020, month, 20).in_time_zone }
    end

    def create_event_with_schedule
      item = create_event
      update_event(item, { schedule: [{ event_date: event_date_range(1) }] })
    end

    def create_event_with_overlay_schedule
      item = create_event
      update_event(item, {
        schedule: [{ event_date: event_date_range(1) }],
        overlay: [{ schedule: [{ event_date: event_date_range(2) }] }]
      })
    end

    def create_event_with_image(image, overlay_image)
      item = create_event
      data_hash = {
        image: [image]
      }
      data_hash[:overlay] = [{ image: [overlay_image].compact }.compact].compact if overlay_image.present?
      update_event(item, data_hash)
    end

    def create_schedule(dtstart, dtend, duration)
      schedule = DataCycleCore::Schedule.new
      dtstart = Time.parse(dtstart).in_time_zone
      dtend = Time.parse(dtend).in_time_zone
      end_time = dtstart + duration
      schedule.schedule_object = IceCube::Schedule.new(dtstart, end_time: end_time) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9).until(dtend))
      end
      schedule.schedule_object.to_hash.merge(dtstart: dtstart, dtend: dtend).compact
    end

    def create_event_with_event_schedule(schedule_hash, overlay_schedule_hash)
      item = create_event
      data_hash = {
        event_schedule: Array.wrap(schedule_hash)
      }
      data_hash[:overlay] = [{ event_schedule: Array.wrap(overlay_schedule_hash).compact }.compact].compact if overlay_schedule_hash.present?
      update_event(item, data_hash)
    end

    test 'event with schedule' do
      event = create_event_with_schedule
      serialized_event = event.to_sync_data
      errors = event.set_data_hash(data_hash: serialized_event.except('included'))
      byebug
    end
  end
end
