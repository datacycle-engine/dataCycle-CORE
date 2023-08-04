# frozen_string_literal: true

require 'test_helper'
require 'virtual_attributes_test_utilities'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe 'DataCycleCore::Utility::Virtual::Common#take_first_linked' do
  include VirtualAttributeTestUtilities

  subject do
    DataCycleCore::Utility::Virtual::Common
  end

  it 'should take first linked' do
    content = create_content_dummy({
      my_linked: [
        {
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One'
        }, {
          id: '00000000-0000-0000-0000-000000000002',
          name: 'Two'
        }, {
          id: '00000000-0000-0000-0000-000000000003',
          name: 'Three'
        }
      ]
    })
    content.my_linked.extend(Module.new do
      def limit(n)
        take(n)
      end
    end)

    value = subject.take_first_linked(virtual_parameters: ['my_linked'], content:)

    assert_equal(1, value.size)
    assert_equal('00000000-0000-0000-0000-000000000001', value.first['id'])
    assert_equal('One', value.first['name'])
  end

  it 'should handle empty property' do
    content = create_content_dummy({
      my_linked: []
    })
    content.my_linked.extend(Module.new do
      def limit(n)
        take(n)
      end
    end)

    value = subject.take_first_linked(virtual_parameters: ['my_linked'], content:)

    assert_equal(0, value.size)
  end

  it 'should handle missing property' do
    content = create_content_dummy({
      different_linked: []
    })

    value = subject.take_first_linked(virtual_parameters: ['my_linked'], content:)

    assert_equal(0, value.size)
  end
end
