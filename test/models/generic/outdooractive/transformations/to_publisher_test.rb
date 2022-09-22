# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe 'DataCycleCore::Generic::OutdoorActive::Transformations#to_publisher' do
  subject do
    DataCycleCore::Generic::OutdoorActive::Transformations
  end

  it 'should extract publisher from source' do
    raw_data = {
      'meta' => {
        'source' => {
          'id' => '123456',
          'name' => 'My Publisher',
          'url' => 'https://my.publisher.com'
        }
      }
    }

    processed_data = subject.to_publisher.call(raw_data)

    assert_equal(3, processed_data.size)

    assert_equal('123456', processed_data['external_key'])
    assert_equal('My Publisher', processed_data['name'])

    assert_equal(1, processed_data['contact_info'].size)
    assert_equal('https://my.publisher.com', processed_data['contact_info']['url'])
  end
end
