# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe 'DataCycleCore::Generic::Common::Functions#select_keys' do
  subject do
    DataCycleCore::Generic::Common::Functions
  end

  it 'should select single key' do
    data = {
      'key_1' => 'VALUE 1',
      'key_2' => 'VALUE 2'
    }

    transformed_data = subject.select_keys(data, 'key_1')

    assert_equal(1, transformed_data.keys.size)
    assert_equal('key_1', transformed_data.keys.first)
    assert_equal('VALUE 1', transformed_data.values.first)
  end

  it 'should select multiple keys' do
    data = {
      'key_1' => 'VALUE 1',
      'key_2' => 'VALUE 2',
      'key_3' => 'VALUE 3',
      'key_4' => 'VALUE 4',
      'key_5' => 'VALUE 5'
    }

    transformed_data = subject.select_keys(data, 'key_1', 'key_3')

    assert_equal(2, transformed_data.keys.size)

    assert_equal('key_1', transformed_data.keys.first)
    assert_equal('VALUE 1', transformed_data.values.first)

    assert_equal('key_3', transformed_data.keys.second)
    assert_equal('VALUE 3', transformed_data.values.second)
  end
end
