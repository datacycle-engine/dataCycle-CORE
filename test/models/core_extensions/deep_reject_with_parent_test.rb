# frozen_string_literal: true

require 'test_helper'

class DeepRejectWithParentTest < ActiveSupport::TestCase
  setup do
    @data = {
      'level1_a' => {
        'keep_me' => 'value1',
        'remove_me' => 'value2',
        'level2_a' => {
          'keep_me_too' => 'value3',
          'remove_me' => 'value4'
        },
        'level2_b' => [
          { 'keep_array_item' => 'value5', 'remove_me' => 'value6' },
          { 'keep_array_item' => 'value7', 'remove_me' => 'value8' }
        ]
      },
      'level1_b' => [
        { 'keep_me_array' => 'value9', 'remove_me' => 'value10' },
        { 'keep_me_array' => 'value11', 'remove_me' => 'value12' }
      ],
      'remove_me' => 'value13'
    }
  end

  test 'deep_reject_with_parent removes keys like deep_reject' do
    expected_result = {
      'level1_a' => {
        'keep_me' => 'value1',
        'level2_a' => {
          'keep_me_too' => 'value3'
        },
        'level2_b' => [
          { 'keep_array_item' => 'value5' },
          { 'keep_array_item' => 'value7' }
        ]
      },
      'level1_b' => [
        { 'keep_me_array' => 'value9' },
        { 'keep_me_array' => 'value11' }
      ]
    }

    result = @data.deep_reject! do |k, _v, _parent|
      k == 'remove_me'
    end

    assert_equal expected_result, result
    assert_equal expected_result, @data
  end

  test 'deep_reject_with_parent rejects only nested value' do
    expected_result = {
      'level1_a' => {
        'keep_me' => 'value1',
        'remove_me' => 'value2',
        'level2_a' => {
          'keep_me_too' => 'value3'
        },
        'level2_b' => [
          { 'keep_array_item' => 'value5', 'remove_me' => 'value6' },
          { 'keep_array_item' => 'value7', 'remove_me' => 'value8' }
        ]
      },
      'level1_b' => [
        { 'keep_me_array' => 'value9', 'remove_me' => 'value10' },
        { 'keep_me_array' => 'value11', 'remove_me' => 'value12' }
      ],
      'remove_me' => 'value13'
    }

    result = @data.deep_reject! do |k, _v, parent|
      k == 'remove_me' && parent.key?('keep_me_too')
    end

    assert_equal expected_result, result
    assert_equal expected_result, @data
  end

  test 'deep_reject_with_parent rejects all except nested value' do
    expected_result = {
      'level1_a' => {
        'keep_me' => 'value1',
        'level2_a' => {
          'keep_me_too' => 'value3',
          'remove_me' => 'value4'
        },
        'level2_b' => [
          { 'keep_array_item' => 'value5' },
          { 'keep_array_item' => 'value7' }
        ]
      },
      'level1_b' => [
        { 'keep_me_array' => 'value9' },
        { 'keep_me_array' => 'value11' }
      ]
    }

    result = @data.deep_reject! do |k, _v, parent|
      k == 'remove_me' && !parent.key?('keep_me_too')
    end

    assert_equal expected_result, result
    assert_equal expected_result, @data
  end

  test 'deep_reject_with_parent rejects correct nested value inside array' do
    expected_result = {
      'level1_a' => {
        'keep_me' => 'value1',
        'remove_me' => 'value2',
        'level2_a' => {
          'keep_me_too' => 'value3',
          'remove_me' => 'value4'
        },
        'level2_b' => [
          { 'keep_array_item' => 'value5', 'remove_me' => 'value6' },
          { 'keep_array_item' => 'value7' }
        ]
      },
      'level1_b' => [
        { 'keep_me_array' => 'value9', 'remove_me' => 'value10' },
        { 'keep_me_array' => 'value11', 'remove_me' => 'value12' }
      ],
      'remove_me' => 'value13'
    }

    result = @data.deep_reject! do |k, _v, parent|
      k == 'remove_me' && parent['keep_array_item'] == 'value7'
    end

    assert_equal expected_result, result
    assert_equal expected_result, @data
  end

  test 'deep_reject_with_parent correctly rejects empty arrays' do
    expected_result = {
      'level1_a' => {
        'keep_me' => 'value1',
        'remove_me' => 'value2',
        'level2_a' => {
          'keep_me_too' => 'value3',
          'remove_me' => 'value4'
        }
      },
      'remove_me' => 'value13'
    }

    result = @data.deep_reject! do |k, v, parent|
      (k.in?(['remove_me', 'keep_array_item', 'keep_me_array']) && (parent.key?('keep_array_item') || parent.key?('keep_me_array') || parent.keys == ['remove_me'])) || v.blank?
    end

    assert_equal expected_result, result
    assert_equal expected_result, @data
  end
end
