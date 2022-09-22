# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe 'DataCycleCore::Generic::Common::TransformationUtilities#resolve_attribute_path' do
  subject do
    Object.new.extend(DataCycleCore::Generic::Common::TransformationUtilities)
  end

  it 'should resolve simple attribute key' do
    data = {
      'plain_string_attribute' => 'value',
      'plain_array_attribute' => [1, 2, 3]
    }

    assert_equal('value', subject.resolve_attribute_path(data, 'plain_string_attribute'))
    assert_equal([1, 2, 3], subject.resolve_attribute_path(data, 'plain_array_attribute'))
  end

  it 'should resolve nested attribute keys' do
    data = {
      'level_1' => {
        'level_2' => {
          'level_3' => 'value'
        }
      },
      'level_a' => {
        'level_b' => {
          'level_c' => [1, 2, 3, 4, 5]
        }
      }
    }

    assert_equal('value', subject.resolve_attribute_path(data, ['level_1', 'level_2', 'level_3']))
    assert_equal([1, 2, 3, 4, 5], subject.resolve_attribute_path(data, ['level_a', 'level_b', 'level_c']))
  end

  it 'should resolve attributes contained in array' do
    data = {
      'array' => [
        { 'attribute' => 1 },
        { 'attribute' => 2 }
      ]
    }

    assert_equal([1, 2], subject.resolve_attribute_path(data, ['array', 'attribute']))
  end

  it 'should resolve attributes contained in nested array' do
    data = {
      'array_1' => [
        {
          'attribute_a' => {
            'array_2' => [
              { 'attribute_b' => 'A' },
              { 'attribute_b' => 'B' }
            ]
          }
        },
        {
          'attribute_a' => {
            'array_2' => [
              { 'attribute_b' => 'C' },
              { 'attribute_b' => 'D' },
              { 'attribute_b' => 'E' }
            ]
          }
        }
      ]
    }

    assert_equal(
      ['A', 'B', 'C', 'D', 'E'],
      subject.resolve_attribute_path(data, ['array_1', 'attribute_a', 'array_2', 'attribute_b'])
    )
  end

  it 'should handle nil values' do
    data = {
      'level_1' => {
        'level_2' => nil
      },
      'level_a' => nil
    }

    assert_nil(subject.resolve_attribute_path(data, ['level_1', 'level_2', 'level_3']))
    assert_nil(subject.resolve_attribute_path(data, ['level_a', 'level_b', 'level_c']))
  end
end
