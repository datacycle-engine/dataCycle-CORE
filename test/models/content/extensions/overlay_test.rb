# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class OverlaySimpleTest < ActiveSupport::TestCase
    setup do
      @poi = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: { name: 'Test POI 1', text: 'Test Text', address: { address_country: 'A' } }
      )
      @poi_with_overlay = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: { name: 'Test POI 2' }
      )
      @poi_with_overlay.set_data_hash(
        data_hash: {
          name: 'Test POI 2',
          text: 'Test Text',
          address: { address_country: 'A', address_locality: 'Villach' },
          overlay: [{ name: 'Test Overlay', text: 'Text Overlay', address: { address_country: 'D' } }]
        }
      )
    end

    test 'test overlay of simple attribute(column), no overlay present' do
      assert_equal('Test POI 1', @poi.name)
      assert_equal('Test POI 1', @poi.name_overlay)
    end

    test 'test overlay of simple attribute(column), overlay with data present' do
      assert_equal('Test POI 2', @poi_with_overlay.name)
      assert_equal('Test Overlay', @poi_with_overlay.name_overlay)
    end

    test 'test translated_value, no overlay present' do
      assert_equal('Test Text', @poi.text)
      assert_equal('Test Text', @poi.text_overlay)
    end

    test 'test translated_value, overlay with data present' do
      assert_equal('Test Text', @poi_with_overlay.text)
      assert_equal('Text Overlay', @poi_with_overlay.text_overlay)
    end

    test 'test simple_object, no overlay present' do
      assert_equal({ 'address_country' => 'A' }, @poi.address.to_h)
      assert_equal({ 'address_country' => 'A' }, @poi.address_overlay.to_h)
    end

    test 'test simple_object, overlay with data present' do
      assert_equal({ 'address_country' => 'A', 'address_locality' => 'Villach' }, @poi_with_overlay.address.to_h)
      assert_equal({ 'address_country' => 'D', 'address_locality' => 'Villach' }, @poi_with_overlay.address_overlay.to_h)
    end
  end
end
