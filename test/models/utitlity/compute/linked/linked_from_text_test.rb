# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class LinkedFromTextTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @linked_content = TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: { name: 'linked-from-text-place-1 test' })
      @new_content = TestPreparations.create_content(template_name: 'Linked-Creative-Work-1', data_hash: { name: 'test-linked-in-text organization' })
    end

    def subject_method(text, content = @new_content)
      DataCycleCore::Utility::Compute::Linked.linked_from_text(
        content: content,
        key: 'linked_in_text',
        computed_definition: {
          'compute' => {
            'parameters' => ['description']
          }
        },
        computed_parameters: {
          'description' => text
        }
      )
    end

    test 'return no ids for linked from text' do
      value = subject_method('testsdfksjdhflksdf')
      assert_equal([], value)
    end

    test 'return one id for linked from text' do
      value = subject_method('<span class="dc--contentlink dcjs-tooltip" data-href="7c01ad30-a099-45d8-8366-5542a2b8dd3f">sdfadfa</span>')
      assert_equal(['7c01ad30-a099-45d8-8366-5542a2b8dd3f'], value)
    end

    test 'return multiple ids for linked from text' do
      value = subject_method('<span class="dc--contentlink dcjs-tooltip" data-href="7c01ad30-a099-45d8-8366-5542a2b8dd3f">sdfadfa</span> teksjhdlfkjsbdfsd <span class="dc--contentlink dcjs-tooltip" data-href="8c01ad30-a099-45d8-8366-5542a2b8dd3f">sdfadfa</span>')
      assert_equal(['7c01ad30-a099-45d8-8366-5542a2b8dd3f', '8c01ad30-a099-45d8-8366-5542a2b8dd3f'], value)
    end

    test 'return no ids with empty value for linked from text' do
      value = subject_method('')
      assert_equal([], value)
    end

    test 'return no ids with nil value for linked from text' do
      value = subject_method(nil)
      assert_equal([], value)
    end
  end
end
