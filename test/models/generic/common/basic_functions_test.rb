# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Generic::Common::Transformations::BasicFunctions do
  include DataCycleCore::MinitestSpecHelper

  subject { DataCycleCore::Generic::Common::Transformations::BasicFunctions }

  it 'underscores keys' do
    assert_equal({ 'my_key' => 1 }, subject.underscore_keys({ 'MyKey' => 1 }))
  end

  it 'strips string values' do
    assert_equal({ 'a' => 'x', 'b' => 2 }, subject.strip_all({ 'a' => '  x  ', 'b' => 2 }))
  end

  it 'selects keys' do
    assert_equal({ 'a' => 1 }, subject.select_keys({ 'a' => 1, 'b' => 2 }, 'a'))
  end

  it 'ensures keys with nil defaults' do
    result = subject.ensure_keys({ 'a' => '' }, ['a', 'b'])

    assert_nil(result['a'])
    assert_nil(result['b'])
  end

  it 'compacts a hash' do
    assert_equal({ 'a' => 1 }, subject.compact({ 'a' => 1, 'b' => nil }))
  end

  it 'merges hashes' do
    assert_equal({ 'a' => 1, 'b' => 2 }, subject.merge({ 'a' => 1 }, { 'b' => 2 }))
  end

  it 'merges array values' do
    result = subject.merge_array_values({ 'a' => [1], 'b' => [2, 1] }, 'a', 'b')

    assert_equal([1, 2], result['a'])
  end

  it 'adds a field via a function' do
    result = subject.add_field({ 'a' => 1 }, 'b', ->(d) { d['a'] + 1 })

    assert_equal(2, result['b'])
  end

  it 'does not add a field when the condition is false' do
    result = subject.add_field({ 'a' => 1 }, 'b', ->(_d) { 99 }, ->(_d) { false })

    assert_not(result.key?('b'))
  end

  it 'builds a location point from coordinates' do
    result = subject.location({ 'longitude' => '11.0', 'latitude' => '46.0' })

    assert_kind_of(RGeo::Feature::Point, result['location'])
  end

  it 'leaves location nil for blank or zero coordinates' do
    result = subject.location({ 'longitude' => '0', 'latitude' => '0' })

    assert_nil(result['location'])
  end

  it 'parses geom from WKB binary' do
    wkb = RGeo::Geographic.simple_mercator_factory(srid: 4326).point(11.0, 46.0).as_binary
    result = subject.geom_from_binary({ 'geom' => wkb })

    assert_kind_of(RGeo::Feature::Point, result['geom'])
  end

  it 'returns data unchanged when geom is blank' do
    assert_equal({ 'a' => 1 }, subject.geom_from_binary({ 'a' => 1 }))
  end

  it 'parses geom from geojson' do
    result = subject.geom_from_geojson({ 'geometry' => { 'type' => 'Point', 'coordinates' => [11.0, 46.0] } })

    assert_kind_of(RGeo::Feature::Point, result['geom'])
  end

  it 'returns data unchanged when geometry is blank' do
    assert_equal({ 'a' => 1 }, subject.geom_from_geojson({ 'a' => 1 }))
  end
end
