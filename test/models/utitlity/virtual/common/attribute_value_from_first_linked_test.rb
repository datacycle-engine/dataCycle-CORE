# frozen_string_literal: true

require 'test_helper'
require 'virtual_attributes_test_utilities'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe 'DataCycleCore::Utility::Virtual::Common#attribute_value_from_first_linked' do
  include VirtualAttributeTestUtilities

  subject do
    DataCycleCore::Utility::Virtual::Common
  end

  it 'should take attribute from first linked' do
    content = create_content_dummy({
      my_linked: [
        {
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One'
        }, {
          id: '00000000-0000-0000-0000-000000000002',
          name: 'Two'
        }
      ]
    })

    value = subject.attribute_value_from_first_linked(virtual_parameters: ['my_linked', 'name'], content:)

    assert_equal('One', value)
  end

  it 'should handle empty property' do
    content = create_content_dummy({
      my_linked: []
    })

    value = subject.attribute_value_from_first_linked(virtual_parameters: ['my_linked', 'name'], content:)

    assert_nil(value)
  end

  it 'should handle missing property' do
    content = create_content_dummy({
      different_linked: []
    })

    value = subject.attribute_value_from_first_linked(virtual_parameters: ['my_linked', 'name'], content:)

    assert_nil(value)
  end
end
