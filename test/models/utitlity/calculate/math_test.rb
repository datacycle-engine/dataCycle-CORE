# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Utility::Compute::Math do
  subject do
    DataCycleCore::Utility::Compute::Math
  end

  describe 'testing math method: sum' do
    it 'sum of 2 integers' do
      assert_equal(3, subject.sum({ computed_parameters: { key: [1, 2] } }))
    end

    it 'sum of 3 integers' do
      assert_equal(6, subject.sum({ computed_parameters: { key: [1, 2, 3] } }))
    end

    it 'sum of integers and decimals' do
      assert_equal(10, subject.sum({ computed_parameters: { key: [1, 2.5, 3, 3.5] } }))
    end

    it 'sum of integers and decimals and negative integers' do
      assert_equal(5, subject.sum({ computed_parameters: { key: [1, 2.5, 3, 3.5, -5] } }))
    end

    it 'sum of valid and invalid numbers' do
      assert_equal(5, subject.sum({ computed_parameters: { key: [1, 2.5, nil, 'string', 3, 3.5, '', -5] } }))
    end
  end
end
