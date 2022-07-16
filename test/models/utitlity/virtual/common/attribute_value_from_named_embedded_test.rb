# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe 'DataCycleCore::Utility::Virtual::Common#attribute_value_from_named_embedded' do
  subject do
    DataCycleCore::Utility::Virtual::Common
  end

  it 'should extract string value' do
    content = create_content_dummy({
      my_attribute: [{
        name: 'my.name',
        my_value: 'SOME VALUE'
      }]
    })

    virtual_attribute_parameters = [
      { 'attribute' => 'my_attribute', 'name' => 'my.name' },
      { 'attribute' => 'my_value' }
    ]

    value = subject.attribute_value_from_named_embedded(virtual_parameters: virtual_attribute_parameters, content: content)

    assert_equal('SOME VALUE', value)
  end

  it 'should extract numeric value' do
    content = create_content_dummy({
      my_attribute: [{
        name: 'my.name',
        my_value: 7
      }]
    })

    virtual_attribute_parameters = [
      { 'attribute' => 'my_attribute', 'name' => 'my.name' },
      { 'attribute' => 'my_value' }
    ]

    value = subject.attribute_value_from_named_embedded(virtual_parameters: virtual_attribute_parameters, content: content)

    assert_equal(7, value)
  end

  it 'should handle missing attributes' do
    content = create_content_dummy({
      my_attribute: [{
        name: 'my.name',
        my_value: 7
      }]
    })

    virtual_attribute_parameters = [
      { 'attribute' => 'my_attribute', 'name' => 'my.name' },
      { 'attribute' => 'missing_value' }
    ]

    assert_nil(subject.attribute_value_from_named_embedded(virtual_parameters: virtual_attribute_parameters, content: content))

    virtual_attribute_parameters = [
      { 'attribute' => 'missing_value', 'name' => 'my.name' },
      { 'attribute' => 'my_value' }
    ]

    assert_nil(subject.attribute_value_from_named_embedded(virtual_parameters: virtual_attribute_parameters, content: content))
  end

  it 'should handle missing embedded' do
    content = create_content_dummy({
      my_attribute: [{
        name: 'my.name',
        my_value: 7
      }]
    })

    virtual_attribute_parameters = [
      { 'attribute' => 'my_attribute', 'name' => 'missing.name' },
      { 'attribute' => 'my_value' }
    ]

    assert_nil(subject.attribute_value_from_named_embedded(virtual_parameters: virtual_attribute_parameters, content: content))
  end

  def create_content_dummy(data)
    if data.is_a?(Array)
      data.map { |d| create_content_dummy(d) }
    elsif data.is_a?(Hash)
      Struct.new(*data.keys).new(*data.values.map { |d| create_content_dummy(d) })
    else
      data
    end
  end
end
