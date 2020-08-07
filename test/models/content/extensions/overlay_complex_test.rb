# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class OverlayComplexTest < ActiveSupport::TestCase
    def create_event
      DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: { name: 'Test Event' })
    end

    def update_event(event, data_hash)
      event.tap { |t| t.set_data_hash(data_hash: data_hash, partial_update: true, prevent_history: true) }
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
  end
end
