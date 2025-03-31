# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe 'DataCycleCore::Generic::Common::Functions#location' do
  subject do
    DataCycleCore::Generic::Common::Transformations::BasicFunctions
  end

  it 'should accept longitude and latitude as strings' do
    data = {
      'longitude' => '5',
      'latitude' => '5'
    }

    transformed_data = subject.location(data)

    assert(transformed_data['location'].present?)
    assert_equal(5.0, transformed_data['location'].x)
    assert_equal(5.0, transformed_data['location'].y)
  end

  it 'should accept longitude and latitude as integers' do
    data = {
      'longitude' => 5,
      'latitude' => 5
    }

    transformed_data = subject.location(data)

    assert(transformed_data['location'].present?)
    assert_equal(5.0, transformed_data['location'].x)
    assert_equal(5.0, transformed_data['location'].y)
  end

  it 'should accept longitude and latitude as nil values' do
    data = {
      'longitude' => nil,
      'latitude' => nil
    }

    transformed_data = subject.location(data)

    assert_nil(transformed_data['location'])
  end

  it 'should override existing location key' do
    data = {
      'longitude' => nil,
      'latitude' => nil,
      'location' => 'some location'
    }

    transformed_data = subject.location(data)

    assert_nil(transformed_data['location'])
  end

  it 'should convert zero for longitude and latitude to nil location' do
    data = {
      'longitude' => 0,
      'latitude' => 0
    }

    transformed_data = subject.location(data)

    assert_nil(transformed_data['location'])
  end
end
