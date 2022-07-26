# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe 'DataCycleCore::Generic::OutdoorActive::Transformations#to_author' do
  subject do
    DataCycleCore::Generic::OutdoorActive::Transformations
  end

  it 'should extract author with plain name' do
    raw_data = {
      'author' => 'Some One'
    }

    processed_data = subject.to_author.call(raw_data)

    assert_equal(2, processed_data.size)

    assert_equal('Some One', processed_data['name'])
    assert(processed_data['external_key'].present?)
  end

  it 'should extract author with plain name from meta' do
    raw_data = {
      'meta' => {
        'author' => 'Some One'
      }
    }

    processed_data = subject.to_author.call(raw_data)

    assert_equal(2, processed_data.size)

    assert_equal('Some One', processed_data['name'])
    assert(processed_data['external_key'].present?)
  end

  it 'should extract full author' do
    raw_data = {
      'meta' => {
        'authorFull' => {
          'id' => '123456',
          'name' => 'Some One'
        }
      }
    }

    processed_data = subject.to_author.call(raw_data)

    assert_equal(2, processed_data.size)

    assert_equal('Some One', processed_data['name'])
    assert_equal('123456', processed_data['external_key'])
  end
end
