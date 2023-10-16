# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Differs::Geographic do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Differs::Geographic
  end

  describe 'diff data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'geographic',
        'storage_location' => 'translated_value'
      }
    end

    let(:geo_factory) do
      RGeo::Cartesian.preferred_factory
    end

    it 'properly diffs equal geographic points' do
      a_val = RGeo::Geographic.simple_mercator_factory.point(10, 20)
      a_string = a_val.to_s
      [[a_val, a_val], [a_string, a_val], [a_val, a_string]].each do |a, b|
        assert_nil(subject.new(a, b).diff_hash)
        assert_nil(subject.new(a, b, template_hash).diff_hash)
      end
    end

    it 'recognizes a deleted value' do
      a = RGeo::Geographic.simple_mercator_factory.point(10, 20)
      [a, a.to_s].each do |item|
        assert_equal(['-', a], subject.new(item, nil).diff_hash)
      end
    end

    it 'recognizes an inserted value' do
      a = RGeo::Geographic.simple_mercator_factory.point(10, 20)
      [a, a.to_s].each do |item|
        assert_equal(['+', a], subject.new(nil, item, template_hash).diff_hash)
        assert_equal(['+', a], subject.new(nil, item).diff_hash)
      end
    end

    it 'recognizes similar points as equal' do
      a = RGeo::Geographic.simple_mercator_factory.point(10.000000001, 20.0)
      b = RGeo::Geographic.simple_mercator_factory.point(10.0, 20.000000001)
      [[a, b], [b, a]].each do |item|
        assert_nil(subject.new(item[0], item[1]).diff_hash)
      end
    end

    it 'recognizes linestring with different directions as different' do
      a = geo_factory.line(geo_factory.point(10, 20), geo_factory.point(30, 25))
      b = geo_factory.line(geo_factory.point(30, 25), geo_factory.point(10, 20))

      [[a, b], [b, a]].each do |item|
        assert_not_nil(subject.new(item[0], item[1]).diff_hash)
      end
    end
  end
end
