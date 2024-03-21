# frozen_string_literal: true

require 'test_helper'
require 'virtual_attributes_test_utilities'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe 'DataCycleCore::Utility::Virtual::Common#overlay' do
  include VirtualAttributeTestUtilities

  subject do
    DataCycleCore::Utility::Virtual::Common
  end

  it 'should take override for boolean' do
    content = create_content_dummy({ is_true: true, is_true_override: false })
    value = subject.overlay(virtual_parameters: ['is_true', 'is_true_override'], content:, virtual_definition: { 'type' => 'boolean' })

    assert_equal(false, value)
  end

  it 'should take original for boolean with blank override' do
    content = create_content_dummy({ is_true: true, is_true_override: nil })
    value = subject.overlay(virtual_parameters: ['is_true', 'is_true_override'], content:, virtual_definition: { 'type' => 'boolean' })

    assert_equal(true, value)
  end

  it 'should take override for string' do
    content = create_content_dummy({ name: 'test', name_override: 'Test Overlay' })
    value = subject.overlay(virtual_parameters: ['name', 'name_override'], content:, virtual_definition: { 'type' => 'string' })

    assert_equal('Test Overlay', value)
  end

  it 'should work with blank values for string' do
    content = create_content_dummy({ name: '', name_override: '' })
    value = subject.overlay(virtual_parameters: ['name', 'name_override'], content:, virtual_definition: { 'type' => 'string' })

    assert_equal('', value)
  end

  it 'should take original for string if override is blank' do
    content = create_content_dummy({ name: 'test', name_override: '' })
    value = subject.overlay(virtual_parameters: ['name', 'name_override'], content:, virtual_definition: { 'type' => 'string' })

    assert_equal('test', value)
  end

  it 'should take override for linked' do
    content = create_content_dummy({
      my_linked: [
        {
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One'
        }
      ],
      my_linked_override: [{
        id: '00000000-0000-0000-0000-000000000002',
        name: 'Two'
      }, {
        id: '00000000-0000-0000-0000-000000000003',
        name: 'Three'
      }],
      my_linked_add: DataCycleCore::Thing.none
    })
    value = subject.overlay(virtual_parameters: ['my_linked', 'my_linked_override', 'my_linked_add'], content:, virtual_definition: { 'type' => 'linked' })

    assert(value.is_a?(ActiveRecord::Relation))
    assert(value.first.is_a?(DataCycleCore::Thing))
    assert_equal(2, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'], value.pluck(:id))
  end

  it 'should take original for linked if override is blank' do
    content = create_content_dummy({
      my_linked: [
        {
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One'
        }
      ],
      my_linked_override: DataCycleCore::Thing.none,
      my_linked_add: DataCycleCore::Thing.none
    })
    value = subject.overlay(virtual_parameters: ['my_linked', 'my_linked_override', 'my_linked_add'], content:, virtual_definition: { 'type' => 'linked' })

    assert(value.is_a?(ActiveRecord::Relation))
    assert(value.first.is_a?(DataCycleCore::Thing))
    assert_equal(1, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001'], value.pluck(:id))
  end

  it 'should take override for embedded' do
    content = create_content_dummy({
      my_embedded: [
        {
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One'
        }
      ],
      my_embedded_override: [{
        id: '00000000-0000-0000-0000-000000000002',
        name: 'Two'
      }, {
        id: '00000000-0000-0000-0000-000000000003',
        name: 'Three'
      }],
      my_embedded_add: DataCycleCore::Thing.none
    })
    value = subject.overlay(virtual_parameters: ['my_embedded', 'my_embedded_override', 'my_embedded_add'], content:, virtual_definition: { 'type' => 'embedded' })

    assert(value.is_a?(ActiveRecord::Relation))
    assert(value.first.is_a?(DataCycleCore::Thing))
    assert_equal(2, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'], value.pluck(:id))
  end

  it 'should take original for embedded if override is blank' do
    content = create_content_dummy({
      my_embedded: [
        {
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One'
        }
      ],
      my_embedded_override: DataCycleCore::Thing.none,
      my_embedded_add: DataCycleCore::Thing.none
    })
    value = subject.overlay(virtual_parameters: ['my_embedded', 'my_embedded_override', 'my_embedded_add'], content:, virtual_definition: { 'type' => 'embedded' })

    assert(value.is_a?(ActiveRecord::Relation))
    assert(value.first.is_a?(DataCycleCore::Thing))
    assert_equal(1, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001'], value.pluck(:id))
  end

  it 'should combine original with add for classification' do
    content = create_content_dummy({
      my_classification:
        create_classification_dummy([{
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One'
        }]),
      my_classification_add: create_classification_dummy([{
        id: '00000000-0000-0000-0000-000000000002',
        name: 'Two'
      }, {
        id: '00000000-0000-0000-0000-000000000003',
        name: 'Three'
      }])
    })
    value = subject.overlay(virtual_parameters: ['my_classification', 'my_classification_add'], content:, virtual_definition: { 'type' => 'classification' })

    assert(value.is_a?(ActiveRecord::Relation))
    assert(value.first.is_a?(DataCycleCore::Classification))
    assert_equal(3, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'], value.pluck(:id))
  end

  it 'should take orignal for classification if add is blank' do
    content = create_content_dummy({
      my_classification:
        create_classification_dummy([{
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One'
        }]),
      my_classification_add: DataCycleCore::Classification.none
    })
    value = subject.overlay(virtual_parameters: ['my_classification', 'my_classification_override', 'my_classification_add'], content:, virtual_definition: { 'type' => 'classification' })

    assert(value.is_a?(ActiveRecord::Relation))
    assert(value.first.is_a?(DataCycleCore::Classification))
    assert_equal(1, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001'], value.pluck(:id))
  end

  it 'should combine original with add for linked' do
    content = create_content_dummy({
      my_linked: [
        {
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One'
        }
      ],
      my_linked_override: nil,
      my_linked_add: [{
        id: '00000000-0000-0000-0000-000000000002',
        name: 'Two'
      }, {
        id: '00000000-0000-0000-0000-000000000003',
        name: 'Three'
      }]
    })
    value = subject.overlay(virtual_parameters: ['my_linked', 'my_linked_override', 'my_linked_add'], content:, virtual_definition: { 'type' => 'linked' })

    assert(value.is_a?(ActiveRecord::Relation))
    assert(value.first.is_a?(DataCycleCore::Thing))
    assert_equal(3, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'], value.pluck(:id))
  end

  it 'should take override for schedule' do
    content = create_content_dummy({
      my_schedule: create_schedule_dummy([{
        id: '00000000-0000-0000-0000-000000000001'
      }]),
      my_schedule_override: create_schedule_dummy([{
        id: '00000000-0000-0000-0000-000000000002'
      }, {
        id: '00000000-0000-0000-0000-000000000003'
      }]),
      my_schedule_add: DataCycleCore::Thing.none
    })
    value = subject.overlay(virtual_parameters: ['my_schedule', 'my_schedule_override', 'my_schedule_add'], content:, virtual_definition: { 'type' => 'schedule' })

    assert(value.is_a?(ActiveRecord::Relation))
    assert(value.first.is_a?(DataCycleCore::Schedule))
    assert_equal(2, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'], value.pluck(:id))
  end

  it 'should take original for schedule if override is blank' do
    content = create_content_dummy({
      my_schedule: create_schedule_dummy([{
        id: '00000000-0000-0000-0000-000000000001'
      }]),
      my_schedule_override: DataCycleCore::Thing.none,
      my_schedule_add: DataCycleCore::Thing.none
    })
    value = subject.overlay(virtual_parameters: ['my_schedule', 'my_schedule_override', 'my_schedule_add'], content:, virtual_definition: { 'type' => 'schedule' })

    assert(value.is_a?(ActiveRecord::Relation))
    assert(value.first.is_a?(DataCycleCore::Schedule))
    assert_equal(1, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001'], value.pluck(:id))
  end

  it 'should combine original with add for schedule' do
    content = create_content_dummy({
      my_schedule: create_schedule_dummy([{
        id: '00000000-0000-0000-0000-000000000001'
      }]),
      my_schedule_override: nil,
      my_schedule_add: create_schedule_dummy([{
        id: '00000000-0000-0000-0000-000000000002'
      }, {
        id: '00000000-0000-0000-0000-000000000003'
      }])
    })
    value = subject.overlay(virtual_parameters: ['my_schedule', 'my_schedule_override', 'my_schedule_add'], content:, virtual_definition: { 'type' => 'schedule' })

    assert(value.is_a?(ActiveRecord::Relation))
    assert(value.first.is_a?(DataCycleCore::Schedule))
    assert_equal(3, value.size)
    assert_equal(['00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003'], value.pluck(:id))
  end
end
