# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe 'DataCycleCore::Generic::Common::Functions#ensure_keys' do
  subject do
    DataCycleCore::Generic::Common::Transformations::BasicFunctions
  end

  it 'should accept keys and defaults to nil' do
    data = {
      'key_1' => 'VALUE 1',
      'key_2' => 'VALUE 2',
      'other_key' => 'OTHER VALUE'
    }

    transformed_data = subject.ensure_keys(data, ['key_1', 'key_2', 'key_3'])

    assert_equal(3, transformed_data.keys.size)
    assert_equal('VALUE 1', transformed_data['key_1'])
    assert_equal('VALUE 2', transformed_data['key_2'])
    assert_nil(transformed_data['key_3'])
    assert_equal(false, transformed_data.key?('other_key'))
  end
end
