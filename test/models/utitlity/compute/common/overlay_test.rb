# frozen_string_literal: true

require 'test_helper'
require 'virtual_attributes_test_utilities'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe 'DataCycleCore::Utility::Compute::Common#overlay' do
  include VirtualAttributeTestUtilities

  subject do
    DataCycleCore::Utility::Compute::Common
  end

  it 'should take override for boolean' do
    value = subject.overlay(computed_parameters: { is_true: true, is_true_override: false }, computed_definition: { 'type' => 'boolean' })

    assert_equal(false, value)
  end

  it 'should take original for boolean with blank override' do
    value = subject.overlay(computed_parameters: { is_true: true, is_true_override: nil }, computed_definition: { 'type' => 'boolean' })

    assert_equal(true, value)
  end

  it 'should take override for string' do
    value = subject.overlay(computed_parameters: { name: 'test', name_override: 'Test Overlay' }, computed_definition: { 'type' => 'string' })

    assert_equal('Test Overlay', value)
  end

  it 'should work with blank values for string' do
    value = subject.overlay(computed_parameters: { name: '', name_override: '' }, computed_definition: { 'type' => 'string' })

    assert_equal('', value)
  end

  it 'should take original for string if override is blank' do
    value = subject.overlay(computed_parameters: { name: 'test', name_override: '' }, computed_definition: { 'type' => 'string' })

    assert_equal('test', value)
  end

  it 'should take override for linked' do
    value = subject.overlay(computed_parameters: {
      my_linked: ['00000000-0000-0000-0000-000000000001'],
      my_linked_override: ['00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'],
      my_linked_add: []
    }, computed_definition: { 'type' => 'linked' })

    assert(value.is_a?(Array))
    assert(value.first.uuid?)
    assert_equal(2, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'], value)
  end

  it 'should take original for linked if override is blank' do
    value = subject.overlay(computed_parameters: {
      my_linked: ['00000000-0000-0000-0000-000000000001'],
      my_linked_override: [],
      my_linked_add: []
    }, computed_definition: { 'type' => 'linked' })

    assert(value.is_a?(Array))
    assert(value.first.uuid?)
    assert_equal(1, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001'], value)
  end

  it 'should take override for embedded' do
    assert_raises(StandardError) do
      subject.overlay(computed_parameters: {
        my_embedded: ['00000000-0000-0000-0000-000000000001'],
        my_embedded_override: ['00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'],
        my_embedded_add: []
      }, computed_definition: { 'type' => 'embedded' })
    end
  end

  it 'should take original for embedded if override is blank' do
    assert_raises(StandardError) do
      subject.overlay(computed_parameters: {
        my_embedded: ['00000000-0000-0000-0000-000000000001'],
        my_embedded_override: [],
        my_embedded_add: []
      }, computed_definition: { 'type' => 'embedded' })
    end
  end

  it 'should combine original with add for classification' do
    value = subject.overlay(computed_parameters: {
      my_classification: ['00000000-0000-0000-0000-000000000001'],
      my_classification_add: ['00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003']
    }, computed_definition: { 'type' => 'classification' })

    assert(value.is_a?(Array))
    assert(value.first.uuid?)
    assert_equal(3, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'], value)
  end

  it 'should take orignal for classification if add is blank' do
    value = subject.overlay(computed_parameters: {
      my_classification: ['00000000-0000-0000-0000-000000000001'],
      my_classification_add: []
    }, computed_definition: { 'type' => 'classification' })

    assert(value.is_a?(Array))
    assert(value.first.uuid?)
    assert_equal(1, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001'], value)
  end

  it 'should combine original with add for linked' do
    value = subject.overlay(computed_parameters: {
      my_linked: ['00000000-0000-0000-0000-000000000001'],
      my_linked_override: nil,
      my_linked_add: ['00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003']
    }, computed_definition: { 'type' => 'linked' })

    assert(value.is_a?(Array))
    assert(value.first.uuid?)
    assert_equal(3, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'], value)
  end
end
