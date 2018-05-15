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

  describe 'convert data' do
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

    it 'throws an exception when a boolean can not be converted to a string' do
      test_cases = ['XXX', 503, 59.0]
      test_cases.each do |test_case|
        assert_raises(ArgumentError) { subject.boolean_to_string(test_case) }
      end
    end

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
  end
end
