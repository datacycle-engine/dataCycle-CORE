require 'test_helper'

module DataCycleCore
  class PlaceTest < ActiveSupport::TestCase
    test 'Place exists' do
      data = DataCycleCore::Place.new
      assert_equal(data.class, DataCycleCore::Place)
    end

    test 'save proper Place data-set with hash method' do
      template = DataCycleCore::Place.find_by(template: true, template_name: 'contentLocation')
      data_set = DataCycleCore::Place.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      error = data_set.set_data_hash(data_hash: { 'name' => 'Dies ist ein Test!', 'longitude' => 40.56, 'latitude' => 13.13 })
      data_set.save
      expected_hash = {
        'id' => data_set.id,
        'name' => 'Dies ist ein Test!',
        'longitude' => 40.56,
        'latitude' => 13.13
      }
      assert_equal(expected_hash, data_set.get_data_hash.compact)
    end

    test 'save proper Place data-set with hash method, incl. geo-data' do
      template = DataCycleCore::Place.find_by(template: true, template_name: 'contentLocation')
      data_set = DataCycleCore::Place.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      point = RGeo::Geographic.spherical_factory(srid: 4326).point(40.56, 13.13)
      error = data_set.set_data_hash(data_hash: { 'name' => 'Dies ist ein Test!', 'longitude' => 40.56, 'latitude' => 13.13, 'location' => point })
      data_set.save
      expected_hash = {
        'id' => data_set.id,
        'name' => 'Dies ist ein Test!',
        'longitude' => 40.56,
        'latitude' => 13.13,
        'location' => point
      }

      # location object deserializes with the RGeo::Geos::CAPIFactory != RGeo::Geographic.spherical_factory
      assert_equal(expected_hash.except('location'), data_set.get_data_hash.except('location').compact)
      assert_equal(true, expected_hash['location'].x == data_set.get_data_hash['location'].x)
      assert_equal(true, expected_hash['location'].y == data_set.get_data_hash['location'].y)
      assert_equal(true, expected_hash['location'].srid == data_set.get_data_hash['location'].srid)
    end

    test 'save full Place data-set with hash method' do
      template = DataCycleCore::Place.find_by(template: true, template_name: 'contentLocation')
      data_set = DataCycleCore::Place.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      external_source = DataCycleCore::ExternalSource.new
      external_source.name = 'Test'
      external_source.save
      external_source_id = external_source.id
      point = RGeo::Geographic.spherical_factory(srid: 4326).point(40.56, 13.13)
      error = data_set.set_data_hash(
        data_hash: {
          'name' => 'Dies ist ein Test!',
          'longitude' => 40.56,
          'latitude' => 13.13,
          'location' => point,
          'external_source_id' => external_source_id
        }
      )
      data_set.save
      expected_hash = {
        'id' => data_set.id,
        'name' => 'Dies ist ein Test!',
        'longitude' => 40.56,
        'latitude' => 13.13,
        'location' => point,
        'external_source_id' => external_source_id
      }
      # location object deserializes to RGeo::Geos::CAPIPointImpl != RGeo::Geographic::SphericalPointImpl

      assert_equal(expected_hash.except('location'), data_set.get_data_hash.except('location').compact)
      assert_equal(true, expected_hash['location'].x == data_set.get_data_hash['location'].x) # check for same x-coordinate
      assert_equal(true, expected_hash['location'].y == data_set.get_data_hash['location'].y) # check for same y-coordinate
      assert_equal(true, expected_hash['location'].srid == data_set.get_data_hash['location'].srid) # check for same coordinate system
    end

    test 'create place and add 3 places, check for order' do
      cw_temp = DataCycleCore::CreativeWork.count
      place_temp = DataCycleCore::Place.count

      main_template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'TestEmbeddedPlaceData')

      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = main_template.schema
      data_set.template_name = main_template.template_name
      data_set.save
      place_array = []
      (1..3).each do |number|
        place_array.push({ 'name' => "Ort #{number}" })
      end
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Main',
          'testPlace' => place_array
        },
        prevent_history: true
      )
      data_set.save

      assert_equal(1, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(place_array.size, DataCycleCore::Place.count - place_temp)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::Place::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      stored_places = data_set.testPlace.map(&:name)
      place_array.each_index do |index|
        assert_equal(place_array[index]['name'], stored_places[index])
      end

      stored_ids = data_set.testPlace.map(&:id)
      new_array = []
      (1..3).each do |number|
        new_array.push({ 'id' => stored_ids[number - 1] })
      end

      # set data_links in reversed_order
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Main',
          'testPlace' => [
            new_array[2],
            new_array[1],
            new_array[0]
          ]
        }
      )
      data_set.save

      assert_equal(1, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(new_array.size, DataCycleCore::Place.count - place_temp)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(3, DataCycleCore::Place::History.count)
      assert_equal(3, DataCycleCore::ContentContent::History.count)

      linked_data = data_set.testPlace.map(&:id)
      new_array.each_index do |index|
        assert_equal(new_array[-(index + 1)]['id'], linked_data[index])
      end
    end
  end
end
