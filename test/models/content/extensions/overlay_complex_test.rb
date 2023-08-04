# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class OverlayComplexTest < ActiveSupport::TestCase
    def create_event
      DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: { name: 'Test Event' })
    end

    def update_event(event, data_hash)
      event.set_data_hash(data_hash:, partial_update: true, prevent_history: true)
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
      schedule.schedule_object = IceCube::Schedule.new(dtstart, end_time:) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(9).until(dtend))
      end
      schedule.schedule_object.to_hash.merge(dtstart:, dtend:).compact
    end

    def create_event_with_event_schedule(schedule_hash, overlay_schedule_hash)
      item = create_event
      data_hash = {
        event_schedule: Array.wrap(schedule_hash)
      }
      data_hash[:overlay] = [{ event_schedule: Array.wrap(overlay_schedule_hash).compact }.compact].compact if overlay_schedule_hash.present?
      update_event(item, data_hash)
    end

    test 'test overlay of simple attribute(column), no overlay present' do
      event = create_event
      assert_equal('Test Event', event.name)
      assert_equal('Test Event', event.name_overlay)
    end

    test 'test overlay of simple attribute(column), overlay with data present' do
      event = create_event_with_overlay
      assert_equal('Test Event', event.name)
      assert_equal('Test Overlay', event.name_overlay)
    end

    test 'test fallback of property that does not exist in the overlay' do
      event = create_event_with_overlay
      assert_equal(event.data_type, event.data_type_overlay)
    end

    test 'test classifications,set only in event' do
      event = create_event_with_classifications
      assert_equal(event.event_status, event.event_status_overlay)
    end

    test 'test classifications, set differently in event and overlay' do
      event = create_event_with_overlay_classifications
      assert_equal('Veranstaltung geplant', event.event_status.first.name)
      assert_equal('Veranstaltung abgesagt', event.event_status_overlay.first.name)
    end

    test 'event with schedule' do
      event = create_event_with_schedule
      assert_equal(event.schedule, event.schedule_overlay)
      assert_equal(event_date_range(1).stringify_keys, event.schedule_overlay.first.get_data_hash.dig('event_date'))
    end

    test 'event with overlayed schedule' do
      event = create_event_with_overlay_schedule
      assert_equal(event_date_range(1).stringify_keys, event.schedule.first.get_data_hash.dig('event_date'))
      assert_equal(event_date_range(2).stringify_keys, event.schedule_overlay.first.get_data_hash.dig('event_date'))
    end

    test 'event with linked image' do
      image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild' })
      overlay_image = DataCycleCore::DummyDataHelper.create_data('image')

      event = create_event_with_image(image.id, nil)
      assert_equal(0, event.overlay.size)
      assert_equal(image.id, event.image_overlay.first.id)

      event = create_event_with_image(image.id, overlay_image.id)
      assert_not_equal(image.id, overlay_image.id)
      assert_equal(1, event.overlay.size)
      assert_equal(image.id, event.image.first.id)
      assert_equal(overlay_image.id, event.image_overlay.first.id)
    end

    test 'event with proper schedule and computed properties' do
      dtfrom = '2019-11-20T09:00:00'
      dtend = '2020-01-04T16:00:00'
      schedule_hash = create_schedule(dtfrom, dtend, 7.hours)
      odtfrom = '2020-11-20T09:00:00'
      odtend = '2021-01-04T16:00:00'
      overlay_schedule_hash = create_schedule(odtfrom, odtend, 7.hours)

      event = create_event_with_event_schedule(schedule_hash, nil)
      assert_equal(0, event.overlay.size)
      assert_equal(dtfrom, event.start_date.to_s(:long_datetime))
      assert_equal(dtend, event.end_date.to_s(:long_datetime))

      event = create_event_with_event_schedule(schedule_hash, overlay_schedule_hash)
      assert_equal(1, event.overlay.size)
      schedule = event.event_schedule.first.to_h
      schedule_overlay = event.overlay.first.event_schedule.first.to_h
      assert_not_equal(schedule, schedule_overlay)
      assert_equal(schedule_overlay, event.event_schedule_overlay.first.to_h)

      assert_equal(dtfrom, event.start_date.to_s(:long_datetime))
      assert_equal(dtend, event.end_date.to_s(:long_datetime))
      assert_equal(odtfrom, event.overlay.first.start_date.to_s(:long_datetime))
      assert_equal(odtend, event.overlay.first.end_date.to_s(:long_datetime))
      assert_equal(odtfrom, event.start_date_overlay.to_s(:long_datetime))
      assert_equal(odtend, event.end_date_overlay.to_s(:long_datetime))
    end
  end
end
