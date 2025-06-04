# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class LinkedFromTextTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @linked_content = TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: { name: 'linked-from-text-place-1 test' })
      @content = TestPreparations.create_content(template_name: 'Creative-Work-1-With-Translations', data_hash: { name: 'test-linked-in-text organization' })
    end

    def subject_method(description, text, content = @content)
      DataCycleCore::Utility::Compute::Linked.linked_from_text(
        content: content,
        key: 'linked_in_text',
        computed_definition: {
          'compute' => {
            'parameters' => ['description', 'text']
          }
        },
        computed_parameters: {
          'description' => description,
          'text' => text
        }
      )
    end

    test 'return no ids for linked from text' do
      value = subject_method('testsdfksjdhflksdf', nil)
      assert_equal([], value)
    end

    test 'return one id for linked from text' do
      value = subject_method('<span class="dc--contentlink" data-href="7c01ad30-a099-45d8-8366-5542a2b8dd3f">sdfadfa</span>', nil)
      assert_equal(['7c01ad30-a099-45d8-8366-5542a2b8dd3f'], value)
    end

    test 'return multiple ids for linked from text' do
      value = subject_method('<span class="dc--contentlink" data-href="7c01ad30-a099-45d8-8366-5542a2b8dd3f">sdfadfa</span> teksjhdlfkjsbdfsd', '<span class="dc--contentlink" data-href="8c01ad30-a099-45d8-8366-5542a2b8dd3f">sdfadfa</span>')
      assert_equal(['7c01ad30-a099-45d8-8366-5542a2b8dd3f', '8c01ad30-a099-45d8-8366-5542a2b8dd3f'], value)
    end

    test 'return no ids with empty value for linked from text' do
      value = subject_method('', nil)
      assert_equal([], value)
    end

    test 'return no ids with nil value for linked from text' do
      value = subject_method(nil, nil)
      assert_equal([], value)
    end

    test 'return multiple ids for all available locales' do
      I18n.with_locale(:en) do
        @content.set_data_hash(data_hash: { description: "<span class=\"dc--contentlink\" data-href=\"#{@linked_content.id}\">sdfadfa</span> teksjhdlfkjsbdfsd" })
      end

      value = subject_method('<span class="dc--contentlink" data-href="7c01ad30-a099-45d8-8366-5542a2b8dd3f">sdfadfa</span> teksjhdlfkjsbdfsd', '<span class="dc--contentlink" data-href="8c01ad30-a099-45d8-8366-5542a2b8dd3f">sdfadfa</span>')
      assert_equal(['7c01ad30-a099-45d8-8366-5542a2b8dd3f', '8c01ad30-a099-45d8-8366-5542a2b8dd3f', @linked_content.id], value)
    end

    test 'return correct ids for all available locales after changing ids in text' do
      @content.set_data_hash(data_hash: { description: '<span class="dc--contentlink" data-href="7c01ad30-a099-45d8-8366-5542a2b8dd3f">sdfadfa</span> teksjhdlfkjsbdfsd' })

      I18n.with_locale(:en) do
        @content.set_data_hash(data_hash: { description: "<span class=\"dc--contentlink\" data-href=\"#{@linked_content.id}\">sdfadfa</span> teksjhdlfkjsbdfsd" })
      end

      value = subject_method('teksjhdlfkjsbdfsd', '<span class="dc--contentlink" data-href="8c01ad30-a099-45d8-8366-5542a2b8dd3f">sdfadfa</span>')
      assert_equal(['8c01ad30-a099-45d8-8366-5542a2b8dd3f', @linked_content.id], value)
    end
  end
end
