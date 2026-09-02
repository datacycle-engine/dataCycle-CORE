# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Filter
    class OverlayPresentSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def create_overlay_event(name)
        DataCycleCore::TestPreparations.create_content(template_name: 'EventNewOverlay', data_hash: { name: })
      end

      def set_overlay(event, data_hash)
        event.set_data_hash(data_hash:, partial_update: true, prevent_history: true)
        event.reload
        event
      end

      def overlay_filter_ids(value)
        DataCycleCore::Filter::Search.new(locale: :de)
          .template_names('EventNewOverlay')
          .advanced_attributes(value, 'boolean', 'overlay_present')
          .map(&:id)
      end

      test 'EventNewOverlay generates an overlay_present computed advanced-search property with static overlay parameters' do
        definition = DataCycleCore::Thing.new(template_name: 'EventNewOverlay').properties_for('overlay_present')

        assert_not_nil(definition, 'overlay_present should be generated for inline-overlay templates')
        assert_equal('boolean', definition['type'])
        assert_equal('translated_value', definition['storage_location'])
        assert(definition['advanced_search'])
        assert_equal('Overlay', definition.dig('compute', 'module'))
        assert_equal('overlay_present', definition.dig('compute', 'method'))
        assert(definition.dig('compute', 'recompute_on_classification_change'))
        assert_includes(definition.dig('compute', 'parameters'), 'name_override')
        assert_includes(definition.dig('compute', 'parameters'), 'image_override')
      end

      test 'overlay_present defaults to false without overlay values' do
        event = create_overlay_event('No Overlay Event')

        assert_not(event.overlay_present)
      end

      test 'overlay_present flips to true after setting a JSONB (translated) inline overlay and back to false after removing it' do
        event = create_overlay_event('Name Overlay Event')

        assert_not(event.overlay_present)

        set_overlay(event, { name_override: 'Overridden Name' })

        assert(event.overlay_present)

        set_overlay(event, { name_override: '' })

        assert_not(event.overlay_present)
      end

      test 'overlay_present detects a linked inline overlay value (image_override)' do
        image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Original Image' })
        override_image = DataCycleCore::DummyDataHelper.create_data('image')

        event = set_overlay(create_overlay_event('Image Overlay Event'), { image: [image.id], image_override: [override_image.id] })

        assert(event.overlay_present)
      end

      test 'overlay_present is generated for a legacy (embedded) overlay template with the overlay relation as a parameter' do
        definition = DataCycleCore::Thing.new(template_name: 'Event').properties_for('overlay_present')

        assert_not_nil(definition, 'overlay_present should be generated for legacy overlay templates')
        assert_equal('boolean', definition['type'])
        assert_includes(definition.dig('compute', 'parameters'), 'overlay')
      end

      test 'overlay_present flips with a legacy embedded overlay' do
        event = DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: { name: 'Legacy Overlay Event' })

        assert_not(event.overlay_present)

        set_overlay(event, { overlay: [{ name: 'Legacy Overlay' }] })

        assert(event.overlay_present)

        set_overlay(event, { overlay: [] })

        assert_not(event.overlay_present)
      end

      test 'overlay_present advanced filter returns only contents with an inline overlay' do
        without = create_overlay_event('Filter Without Overlay')
        with = set_overlay(create_overlay_event('Filter With Overlay'), { name_override: 'Overridden' })

        [without, with].each { |c| c.reload.update_search('de') }

        true_ids = overlay_filter_ids('true')
        false_ids = overlay_filter_ids('false')

        assert_includes(true_ids, with.id)
        assert_not_includes(true_ids, without.id)

        assert_includes(false_ids, without.id)
        assert_not_includes(false_ids, with.id)
      end
    end
  end
end
