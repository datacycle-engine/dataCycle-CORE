# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Geographic do
  subject do
    DataCycleCore::MasterData::Validators::Geographic
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'geographic',
        'storage_location' => 'translated_value'
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'properly validates a geo object' do
      geo_object = RGeo::Geographic.spherical_factory(srid: 4326).point(12.3, 40.344)
      assert_equal(no_error_hash, subject.new(geo_object, template_hash).error)
    end

    # it 'properly returns a warning if no data are given' do
    #   error_hash = subject.new(nil, template_hash)
    #   assert_equal(0, error_hash.error[:error].size)
    #   assert_equal(1, error_hash.error[:warning].size)
    # end

    it 'rejects arbitrary objects' do
      test_cases = [10, :wednesday, 'POINT (10.0 47.0 hallo)']
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'accepts different geo objects' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      point = factory.point(12.3, 40.344)
      line = factory.line_string([factory.point(1.0, 2.0), factory.point(1.5, 2.5)])
      factory3d = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
      line3d = factory3d.line_string([factory3d.point(1.0, 1.0, 1.0), factory3d.point(1.5, 1.5, 1.5)])
      wkt_string = 'POINT (10.0 47.0)'
      wkt_string3d = 'POINT Z (10.0 47.0 2000)'

      test_cases = [point, line, line3d, wkt_string, wkt_string3d]
      test_cases.each do |test_case|
        validator = subject.new(test_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end
  end
end
