require 'test_helper'

module DataCycleCore
  class PlaceTest < ActiveSupport::TestCase
    test 'Place exists' do
      data = DataCycleCore::Place.new
      assert_equal(data.class, DataCycleCore::Place)
    end

    test 'save proper Place data-set with hash method' do
      template = DataCycleCore::Place.where(template: true, headline: 'contentLocation', description: 'Place').first
      validation = template.metadata['validation']
      data_set = DataCycleCore::Place.new
      data_set.metadata = { 'validation' => validation }
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
      template = DataCycleCore::Place.where(template: true, headline: 'contentLocation', description: 'Place').first
      validation = template.metadata['validation']
      data_set = DataCycleCore::Place.new
      data_set.metadata = { 'validation' => validation }
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
      template = DataCycleCore::Place.where(template: true, headline: 'contentLocation', description: 'Place').first
      validation = template.metadata['validation']
      data_set = DataCycleCore::Place.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      external_source = DataCycleCore::ExternalSource.new
      external_source.name = 'Test'
      external_source.save
      external_source_id = external_source.id
      point = RGeo::Geographic.spherical_factory(srid: 4326).point(40.56, 13.13)
      error = data_set.set_data_hash(data_hash: {
                                       'name' => 'Dies ist ein Test!',
                                       'longitude' => 40.56,
                                       'latitude' => 13.13,
                                       'location' => point,
                                       'external_source_id' => external_source_id
                                     })
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

      # ap data_set.linked_property_names
      # ap data_set.external_source_id
      # ap data_set.get_data_hash

      assert_equal(expected_hash.except('location'), data_set.get_data_hash.except('location').compact)
      assert_equal(true, expected_hash['location'].x == data_set.get_data_hash['location'].x) # check for same x-coordinate
      assert_equal(true, expected_hash['location'].y == data_set.get_data_hash['location'].y) # check for same y-coordinate
      assert_equal(true, expected_hash['location'].srid == data_set.get_data_hash['location'].srid) # check for same coordinate system
    end
  end
end
