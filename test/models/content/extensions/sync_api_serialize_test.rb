# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SyncApiSerializeTest < ActiveSupport::TestCase
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

    def create_event_with_mapped_classification
      item = create_event
      update_event(item, { event_status: [DataCycleCore::Classification.find_by(name: 'Test Veranstaltung geplant').id] })
    end

    def create_event_with_overlay_mapped_classifications
      item = create_event
      update_event(item, {
        event_status: [DataCycleCore::Classification.find_by(name: 'Test Veranstaltung geplant').id],
        overlay: [{ name: 'Test Overlay', event_status: [DataCycleCore::Classification.find_by(name: 'Test Veranstaltung abgesagt').id] }]
      })
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

    test 'event with schedule' do
      event = create_event_with_schedule
      serialized_event = event.to_sync_data
      assert_equal(['de', 'included', 'classifications'].sort, serialized_event.keys.sort)
      main_data = serialized_event['de']
      ['id', 'name', 'schedule', 'template_name', 'updated_at', 'created_at'].each do |attribute|
        assert(main_data[attribute].present?)
      end
      schedule_data = serialized_event.dig('de', 'schedule', 0, 'de')
      ['id', 'event_date', 'template_name', 'updated_at', 'created_at'].each do |attribute|
        assert(schedule_data[attribute].present?)
      end
    end

    test 'event with overlay' do
      event = create_event_with_overlay
      serialized_event = event.to_sync_data
      assert_equal(['de', 'included', 'classifications'].sort, serialized_event.keys.sort)
      main_data = serialized_event['de']
      ['id', 'name', 'description', 'template_name', 'updated_at', 'created_at'].each do |attribute|
        assert(main_data[attribute].present?)
      end
      assert(event.name_overlay, main_data['name'])
      assert(event.description_overlay, main_data['description'])
    end

    test 'event_with_overlay_schedule' do
      event = create_event_with_overlay_schedule
      serialized_event = event.to_sync_data
      assert_equal(['de', 'included', 'classifications'].sort, serialized_event.keys.sort)
      main_data = serialized_event['de']
      ['id', 'name', 'schedule', 'template_name', 'updated_at', 'created_at'].each do |attribute|
        assert(main_data[attribute].present?)
      end
      assert(event_date_range(2), main_data['event_date'])
    end

    test 'event_with_event_schedule' do
      dtfrom = '2019-11-20T09:00:00'
      dtend = '2020-01-04T16:00:00'
      schedule_hash = create_schedule(dtfrom, dtend, 7.hours)
      odtfrom = '2020-11-20T09:00:00.000+01:00'
      odtend = '2021-01-04T16:00:00.000+01:00'
      overlay_schedule_hash = create_schedule(odtfrom, odtend, 7.hours)
      event = create_event_with_event_schedule(schedule_hash, overlay_schedule_hash)

      serialized_event = event.to_sync_data
      assert_equal(['de', 'included', 'classifications'].sort, serialized_event.keys.sort)
      main_data = serialized_event['de']
      ['id', 'name', 'end_date', 'start_date', 'event_schedule', 'template_name', 'updated_at', 'created_at'].each do |attribute|
        assert(main_data[attribute].present?)
      end

      assert_equal(odtfrom, main_data['start_date'])
      assert_equal(odtend, main_data['end_date'])
      assert_equal(odtfrom.in_time_zone, main_data.dig('event_schedule', 0, 'dtstart').in_time_zone)
      assert_equal(odtend.in_time_zone, main_data.dig('event_schedule', 0, 'dtend').in_time_zone)
    end

    test 'event with linked image' do
      image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild' })
      overlay_image = DataCycleCore::DummyDataHelper.create_data('image')
      event = create_event_with_image(image.id, overlay_image.id)

      serialized_event = event.to_sync_data
      assert_equal(['de', 'included', 'classifications'].sort, serialized_event.keys.sort)
      main_data = serialized_event['de']
      ['id', 'name', 'image', 'template_name', 'updated_at', 'created_at'].each do |attribute|
        assert(main_data[attribute].present?)
      end
      assert_equal(overlay_image.id, main_data.dig('image', 0))

      assert_equal(1, serialized_event['included'].size)
      included_image = serialized_event['included'].first
      assert('image', included_image['attribute_name'])
      assert([], included_image['included'])

      included_image_data = included_image['de']
      assert(overlay_image.id, included_image_data['id'])
      ['id', 'name', 'upload_date', 'template_name', 'updated_at', 'created_at'].each do |attribute|
        assert(included_image_data[attribute].present?)
      end
    end

    test 'test classifications,set only in event' do
      event = create_event_with_classifications
      serialized_event = event.to_sync_data
      assert_equal(['de', 'included', 'classifications'].sort, serialized_event.keys.sort)

      assert_equal(event.event_status, event.event_status_overlay)
      serialized_classification = serialized_event['classifications'].detect { |i| i['attribute_name']&.include?('event_status') }
      assert_equal(event.event_status_overlay.first.name, serialized_classification['name'])
    end

    test 'test classifications, set differently in event and overlay' do
      event = create_event_with_overlay_classifications
      serialized_event = event.to_sync_data
      assert_equal('Veranstaltung geplant', event.event_status.first.name)
      assert_equal('Veranstaltung abgesagt', event.event_status_overlay.first.name)

      serialized_classification = serialized_event['classifications'].detect { |i| i['attribute_name'].include?('event_status') }
      assert_equal(event.event_status_overlay.first.name, serialized_classification['name'])
    end

    test 'serialize mapped classifications' do
      event = create_event_with_mapped_classification
      serialized_event = event.to_sync_data
      assert_equal('Veranstaltung', event.data_type.first.name)

      # original Event
      assert_equal(3, event.classifications.size)
      assert_equal(1, event.data_type.size)
      assert_equal(1, event.event_status.size)
      assert_equal(['Test Veranstaltung geplant'], event.event_status.pluck(:name).sort)

      # serialized_event
      assert_equal(1, serialized_event.dig('de', 'universal_classifications').size)
      assert_equal(['Test1'], DataCycleCore::Classification.where(id: serialized_event.dig('de', 'universal_classifications')).pluck(:name))

      # serialized_event classifications
      assert_equal(4, serialized_event['classifications'].size)
      assert_equal(1, serialized_event['classifications'].count { |i| i['attribute_name'].include?('event_status') })
      assert_equal(1, serialized_event['classifications'].count { |i| i['attribute_name'].include?('universal_classifications') })
      assert_equal(['Test Veranstaltung geplant'], serialized_event['classifications'].select { |i| i['attribute_name'].include?('event_status') }.pluck('name').sort)
      assert_equal(['Test1'], serialized_event['classifications'].select { |i| i['attribute_name'].include?('universal_classifications') }.pluck('name').sort)
    end

    test 'serialize mapped classifications overwritten in overlay' do
      event = create_event_with_overlay_mapped_classifications
      serialized_event = event.to_sync_data
      assert_equal('Veranstaltung', event.data_type.first.name)

      assert_equal(1, serialized_event.dig('de', 'universal_classifications').size)
      assert_equal(['Test2'], DataCycleCore::Classification.where(id: serialized_event.dig('de', 'universal_classifications')).pluck(:name))

      assert_equal(4, serialized_event['classifications'].size)
      assert_equal(1, serialized_event['classifications'].count { |i| i['attribute_name'].include?('event_status') })
      assert_equal(1, serialized_event['classifications'].count { |i| i['attribute_name'].include?('universal_classifications') })
      assert_equal(['Test Veranstaltung abgesagt'], serialized_event['classifications'].select { |i| i['attribute_name'].include?('event_status') }.pluck('name').sort)
      assert_equal(['Test2'], serialized_event['classifications'].select { |i| i['attribute_name'].include?('universal_classifications') }.pluck('name').sort)
    end
  end
end
