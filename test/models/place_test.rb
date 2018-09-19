# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class PlaceTest < ActiveSupport::TestCase
    def excepted_attributes
      ['data_pool', 'data_type', 'last_updated_by', 'deleted_by', 'date_modified', 'publication_schedule', 'overlay',
       'tags', 'image', 'stars', 'output_channel', 'source', 'creator', 'regions', 'google_tags', 'xamoom_tags', 'feratel_types',
       'fontend_type', 'primary_image', 'feratel_owners', 'feratel_topics', 'holiday_themes', 'poi_categories', 'tour_categories',
       'outdoor_active_tags', 'feratel_classifications', 'accommodation_categories', 'opening_hours_specification', 'frontend_type']
    end
    test 'Place exists' do
      data = DataCycleCore::Place.new
      assert_equal(data.class, DataCycleCore::Place)
    end

    test 'save proper Place data-set with hash method + test standard properties' do
      template = DataCycleCore::Place.find_by(template: true, template_name: 'Örtlichkeit')
      data_set = DataCycleCore::Place.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_set.set_data_hash(data_hash: { 'name' => 'Dies ist ein Test!', 'longitude' => 40.56, 'latitude' => 13.13 }, update_search_all: false)
      data_set.save
      expected_hash = {
        'id' => data_set.id,
        'name' => 'Dies ist ein Test!',
        'longitude' => 40.56,
        'latitude' => 13.13,
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact.except(*excepted_attributes))
      assert_nil(data_set.desc)
      assert_equal(['name'], data_set.new_content_fields)
      assert_equal(['name', 'address', 'location'], data_set.object_browser_fields)
      assert_equal(data_set.cache_key.to_s, "data_cycle_core/places/#{data_set.id}-#{data_set.updated_at.utc.to_s(:usec)}/data_cycle_core/place/translations/#{data_set.translations.first.id}-#{data_set.translations.first.updated_at.utc.to_s(:usec)}-de")
      assert_nil(data_set.translations.first.desc)

      assert_equal(1, DataCycleCore::Place.where(template: false, template_name: 'Örtlichkeit').count)
      data_set.destroy
      assert_equal(0, DataCycleCore::Place.where(template: false, template_name: 'Örtlichkeit').count)
    end

    test 'save proper Place data-set with hash method, incl. geo-data' do
      template = DataCycleCore::Place.find_by(template: true, template_name: 'Örtlichkeit')
      data_set = DataCycleCore::Place.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      point = RGeo::Geographic.spherical_factory(srid: 4326).point(40.56, 13.13)
      data_set.set_data_hash(data_hash: { 'name' => 'Dies ist ein Test!', 'longitude' => 40.56, 'latitude' => 13.13, 'location' => point })
      data_set.save
      expected_hash = {
        'id' => data_set.id,
        'name' => 'Dies ist ein Test!',
        'longitude' => 40.56,
        'latitude' => 13.13,
        'location' => point
      }
      resulted_hash = data_set.get_data_hash.compact.except(*excepted_attributes)
      # location object deserializes with the RGeo::Geos::CAPIFactory != RGeo::Geographic.spherical_factory
      assert_equal(expected_hash.except('location'), resulted_hash.except('location'))
      assert_equal(true, expected_hash['location'].x == resulted_hash['location'].x)
      assert_equal(true, expected_hash['location'].y == resulted_hash['location'].y)
      assert_equal(true, expected_hash['location'].srid == resulted_hash['location'].srid)
    end

    # TODO: move to emebedded tests
    # test 'create place and add 3 places, check for order' do
    #   cw_temp = DataCycleCore::CreativeWork.count
    #   place_temp = DataCycleCore::Place.count
    #
    #   main_template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'TestEmbeddedPlaceData')
    #
    #   data_set = DataCycleCore::CreativeWork.new
    #   data_set.schema = main_template.schema
    #   data_set.template_name = main_template.template_name
    #   data_set.save
    #   place_array = []
    #   (1..3).each do |number|
    #     place_array.push({ 'name' => "Ort #{number}" })
    #   end
    #   data_set.set_data_hash(
    #     data_hash: {
    #       'name' => 'Main',
    #       'testPlace' => place_array
    #     },
    #     prevent_history: true
    #   )
    #   data_set.save
    #
    #   assert_equal(1, DataCycleCore::CreativeWork.count - cw_temp)
    #   assert_equal(place_array.size, DataCycleCore::Place.count - place_temp)
    #   assert_equal(3, DataCycleCore::ContentContent.count)
    #   assert_equal(0, DataCycleCore::CreativeWork::History.count)
    #   assert_equal(0, DataCycleCore::Place::History.count)
    #   assert_equal(0, DataCycleCore::ContentContent::History.count)
    #
    #   stored_places = data_set.testPlace.map(&:name)
    #   place_array.each_index do |index|
    #     assert_equal(place_array[index]['name'], stored_places[index])
    #   end
    #
    #   stored_ids = data_set.testPlace.map(&:id)
    #   new_array = []
    #   (1..3).each do |number|
    #     new_array.push({ 'id' => stored_ids[number - 1] })
    #   end
    #
    #   # set data_links in reversed_order
    #   data_set.set_data_hash(
    #     data_hash: {
    #       'name' => 'Main',
    #       'testPlace' => [
    #         new_array[2],
    #         new_array[1],
    #         new_array[0]
    #       ]
    #     }
    #   )
    #   data_set.save
    #
    #   assert_equal(1, DataCycleCore::CreativeWork.count - cw_temp)
    #   assert_equal(new_array.size, DataCycleCore::Place.count - place_temp)
    #   assert_equal(3, DataCycleCore::ContentContent.count)
    #   assert_equal(1, DataCycleCore::CreativeWork::History.count)
    #   assert_equal(3, DataCycleCore::Place::History.count)
    #   assert_equal(3, DataCycleCore::ContentContent::History.count)
    #
    #   linked_data = data_set.testPlace.map(&:id)
    #   new_array.each_index do |index|
    #     assert_equal(new_array[-(index + 1)]['id'], linked_data[index])
    #   end
    # end
  end
end
