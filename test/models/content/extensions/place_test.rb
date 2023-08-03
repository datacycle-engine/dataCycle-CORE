# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class PlaceTest < ActiveSupport::TestCase
    test 'save proper Place data-set with hash method + test standard properties' do
      data_set = DataCycleCore::Thing.new(template_name: 'Örtlichkeit')
      data_set.save
      data_set.set_data_hash(data_hash: { 'name' => 'Dies ist ein Test!', 'longitude' => 40.56, 'latitude' => 13.13 }, update_search_all: false)
      data_set.save
      expected_hash = {
        'name' => 'Dies ist ein Test!',
        'longitude' => 40.56,
        'latitude' => 13.13,
        'tags' => [],
        'output_channel' => [],
        'image' => [],
        'overlay' => [],
        'primary_image' => [],
        'marketing_groups' => [],
        'external_status' => [],
        'feratel_facilities_accommodations' => [],
        'feratel_facilities_additional_services' => [],
        'external_content_score' => []
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('place')).except('opening_hours_specification', 'opening_hours_description', 'opening_hours', 'potential_action'))
      assert_nil(data_set.desc)
      assert_equal(['address', 'location'], data_set.object_browser_fields)
      assert_equal(data_set.cache_key.to_s, "data_cycle_core/things/#{data_set.id}/data_cycle_core/thing/translations/#{data_set.translations.first.id}-de")
      assert_equal(data_set.cache_key_with_version.to_s, "data_cycle_core/things/#{data_set.id}/data_cycle_core/thing/translations/#{data_set.translations.first.id}-de-#{data_set.updated_at.utc.to_s(:usec)}")

      assert_equal(1, DataCycleCore::Thing.where(template_name: 'Örtlichkeit').count)
      data_set.destroy
      assert_equal(0, DataCycleCore::Thing.where(template_name: 'Örtlichkeit').count)
    end

    test 'save proper Place data-set with hash method, incl. geo-data' do
      data_set = DataCycleCore::Thing.new(template_name: 'Örtlichkeit')
      data_set.save
      point = RGeo::Geographic.spherical_factory(srid: 4326).point(40.56, 13.13)
      data_set.set_data_hash(data_hash: { 'name' => 'Dies ist ein Test!', 'longitude' => 40.56, 'latitude' => 13.13, 'location' => point })
      data_set.save
      expected_hash = {
        'name' => 'Dies ist ein Test!',
        'longitude' => 40.56,
        'latitude' => 13.13,
        'location' => point.as_text,
        'tags' => [],
        'output_channel' => [],
        'image' => [],
        'overlay' => [],
        'primary_image' => [],
        'marketing_groups' => [],
        'external_status' => [],
        'feratel_facilities_accommodations' => [],
        'feratel_facilities_additional_services' => [],
        'external_content_score' => []
      }
      resulted_hash = data_set.get_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('place'))
      # location object deserializes with the RGeo::Geos::CAPIFactory != RGeo::Geographic.spherical_factory
      assert_equal(expected_hash.except('location', 'opening_hours_specification', 'opening_hours_description', 'opening_hours'), resulted_hash.except('location', 'opening_hours_specification', 'opening_hours', 'opening_hours_description', 'potential_action'))
      assert_equal(expected_hash['location'], resulted_hash['location'])
    end

    test 'tour has correct WKT 1.2 string representation' do
      test_tour = DataCycleCore::DummyDataHelper.create_data('tour')

      assert test_tour.line.as_text.include?('MULTILINESTRING Z')
    end
  end
end
