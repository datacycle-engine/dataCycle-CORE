# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::DataConverter do
  subject do
    DataCycleCore::MasterData::DataConverter
  end

  def implies(a, b)
    a ? b : true
  end

  describe 'convert key' do
    it 'does not touch key items' do
      assert_nil(subject.convert_to_type('key', nil))
      uuid = SecureRandom.uuid
      assert_equal(uuid, subject.convert_to_type('key', uuid))
    end
  end

  describe 'convert booleans' do
    it 'converts properly booleans to strings' do
      test_cases = [true, false, 'true', 'false', '    true     ']
      test_cases.each do |test_case|
        converted_data = subject.boolean_to_string(test_case)
        assert(['true', 'false'].include?(converted_data))
      end
    end

    it 'converts properly to booleans' do
      test_cases = [true, false, 'true', 'false', '    true     ']
      test_cases.each do |test_case|
        converted_data = subject.string_to_boolean(test_case)
        assert([true.class, false.class].include?(converted_data.class))
      end
    end

    it 'handles nil correctly when converting a string to a boolean' do
      assert_nil(subject.string_to_boolean(nil))
    end

    it 'handles nil correctly when converting a boolean to a string' do
      assert_nil(subject.boolean_to_string(nil))
    end

    it 'throws an exception when a string fails to be converted to a boolean' do
      test_cases = ['XXX', 503, 59.0]
      test_cases.each do |test_case|
        assert_raises(ArgumentError) { subject.string_to_boolean(test_case) }
      end
    end

    it 'string_to_boolean can be called again and gives the same result' do
      test_cases = [true, false, 'true', 'false']
      test_cases.each do |test_case|
        assert_equal(subject.string_to_boolean(test_case), subject.string_to_boolean(subject.string_to_boolean(test_case)))
      end
    end

    it 'boolean_to_string can be called again and gives the same result' do
      test_cases = [true, false, 'true', 'false']
      test_cases.each do |test_case|
        assert_equal(subject.boolean_to_string(test_case), subject.boolean_to_string(subject.boolean_to_string(test_case)))
      end
    end

    it 'throws an exception when a boolean can not be converted to a string' do
      test_cases = ['XXX', 503, 59.0]
      test_cases.each do |test_case|
        assert_raises(ArgumentError) { subject.boolean_to_string(test_case) }
      end
    end
  end

  describe 'convert geo objects' do
    it 'converts wkt_strings to geographic objects' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      point = factory.point(12.3, 40.344)
      line = factory.line_string([factory.point(1.0, 2.0), factory.point(1.5, 2.5)])
      factory3d = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
      line3d = factory3d.line_string([factory3d.point(1.0, 1.0, 1.0), factory3d.point(1.5, 1.5, 1.5)])
      wkt_string = 'POINT (10.0 47.0)'
      wkt_string3d = 'POINT (10.0 47.0 200.0)'
      [point, line, line3d, wkt_string, wkt_string3d].each do |test_case|
        converted_data = subject.string_to_geographic(test_case)
        assert(converted_data.methods.include?(:geometry_type))
        assert(implies(test_case.class == converted_data.class, test_case == converted_data))
        assert(implies(test_case.class != converted_data.class, test_case == converted_data.to_s))
      end
    end

    it 'converts geographic data to strings' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      point = factory.point(12.3, 40.344)
      line = factory.line_string([factory.point(1.0, 2.0), factory.point(1.5, 2.5)])
      factory3d = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
      line3d = factory3d.line_string([factory3d.point(1.0, 1.0, 1.0), factory3d.point(1.5, 1.5, 1.5)])
      wkt_string = 'POINT (10.0 47.0)'
      wkt_string3d = 'POINT (10.0 47.0 200.0)'
      [point, line, line3d, wkt_string, wkt_string3d].each do |test_case|
        converted_data = subject.geographic_to_string(test_case)
        assert_equal(test_case.to_s, converted_data)
      end
    end

    it 'handles nil correctly when converting a string to a geographic object' do
      assert_nil(subject.string_to_geographic(nil))
    end

    it 'handles nil correctly when converting a geographic object to a string' do
      assert_nil(subject.geographic_to_string(nil))
    end

    it 'throws an exception when wkt_string can not be converted to a geographic object' do
      test_cases = ['POINT (10.0 47.0', 'POINT (10.0 47.X0', 'POINT (10.0)', 5]
      test_cases.each do |test_case|
        assert_raises(RGeo::Error::ParseError) { subject.string_to_geographic(test_case) }
      end
    end

    it 'throws an exception when geographic object is not valid' do
      test_cases = ['POINT (10.0 47.0', 'POINT (10.0 47.X0', 'POINT (10.0)', 6]
      test_cases.each do |test_case|
        assert_raises(RGeo::Error::ParseError) { subject.geographic_to_string(test_case) }
      end
    end

    it 'string_to_geographic can be called again and gives the same result' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      point = factory.point(12.3, 40.344)
      line = factory.line_string([factory.point(1.0, 2.0), factory.point(1.5, 2.5)])
      factory3d = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
      line3d = factory3d.line_string([factory3d.point(1.0, 1.0, 1.0), factory3d.point(1.5, 1.5, 1.5)])
      wkt_string = 'POINT (10.0 47.0)'
      wkt_string3d = 'POINT (10.0 47.0 200.0)'
      [point, line, line3d, wkt_string, wkt_string3d].each do |test_case|
        assert_equal(subject.string_to_geographic(test_case), subject.string_to_geographic(subject.string_to_geographic(test_case)))
      end
    end

    it 'geographic_to_string can be called again and gives the same result' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      point = factory.point(12.3, 40.344)
      line = factory.line_string([factory.point(1.0, 2.0), factory.point(1.5, 2.5)])
      factory3d = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
      line3d = factory3d.line_string([factory3d.point(1.0, 1.0, 1.0), factory3d.point(1.5, 1.5, 1.5)])
      wkt_string = 'POINT (10.0 47.0)'
      wkt_string3d = 'POINT (10.0 47.0 200.0)'
      [point, line, line3d, wkt_string, wkt_string3d].each do |test_case|
        assert_equal(subject.geographic_to_string(test_case), subject.geographic_to_string(subject.geographic_to_string(test_case)))
      end
    end
  end

  describe 'convert datetime objects' do
    it 'converts string to datetime objects' do
      test_cases = [Time.now.getlocal, Time.zone.now, Time.now.getlocal.to_s, Time.zone.now.to_s, '01.01.2018', '01.01.2018 10:30']
      test_cases.each do |test_case|
        converted_data = subject.string_to_datetime(test_case)
        assert(converted_data.acts_like?(:time))
        assert(implies(test_case.class == converted_data.class, test_case == converted_data))
      end
    end

    it 'converts datetime data to strings' do
      test_cases = [Time.now.getlocal, Time.zone.now, Time.now.getlocal.to_s, Time.zone.now.to_s, '01.01.2018', '01.01.2018 10:30']
      test_cases.each do |test_case|
        converted_data = subject.datetime_to_string(test_case)
        assert_equal(test_case.to_s, converted_data)
      end
    end

    it 'handles nil correctly when converting a string to a datetime object' do
      assert_nil(subject.string_to_datetime(nil))
    end

    it 'handles nil correctly when converting a datetime object to a string' do
      assert_nil(subject.datetime_to_string(nil))
    end

    it 'throws an exception when string can not be converted to a datetime object' do
      test_cases = ['servas', 5, 5.5]
      test_cases.each do |test_case|
        assert_raises(ArgumentError) { subject.string_to_datetime(test_case) }
      end
    end

    it 'throws an exception when datetime object is not valid' do
      test_cases = ['servas', 5, 5.5]
      test_cases.each do |test_case|
        assert_raises(ArgumentError) { subject.datetime_to_string(test_case) }
      end
    end

    it 'string_to_datetime can be called again and gives the same result' do
      test_cases = [Time.now.getlocal, Time.zone.now, Time.now.getlocal.to_s, Time.zone.now.to_s, '01.01.2018', '01.01.2018 10:30']
      test_cases.each do |test_case|
        assert_equal(subject.string_to_datetime(test_case), subject.string_to_datetime(subject.string_to_datetime(test_case)))
      end
    end

    it 'datetime_to_string can be called again and gives the same result' do
      test_cases = [Time.now.getlocal, Time.zone.now, Time.now.getlocal.to_s, Time.zone.now.to_s, '01.01.2018', '01.01.2018 10:30']
      test_cases.each do |test_case|
        assert_equal(subject.datetime_to_string(test_case), subject.datetime_to_string(subject.datetime_to_string(test_case)))
      end
    end
  end

  describe 'convert string to strings' do
    it 'normalizes unicode' do
      a = "Henry\u2163"
      b = 'HenryIV'
      assert_equal(subject.string_to_string(a), subject.string_to_string(b))
    end
  end
end
