# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class LinkedFromTextAttributeTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @linked1 = TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: { name: 'linked-from-text-place-1 test' })
      @linked2 = TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: { name: 'linked-from-text-place-2 test' })
      @content = TestPreparations.create_content(
        template_name: 'Creative-Work-1-With-Translations',
        data_hash: {
          name: 'test-linked-in-text organization',
          description: "<span class=\"dc--contentlink\" data-href=\"#{@linked1.id}\">sdfadfa</span> ksjdfksjbndfksdf <span class=\"dc--contentlink\" data-href=\"#{@linked2.id}\">sdfadfa</span>",
          text: 'Testtext'
        }
      )
    end

    test 'remove_id_from_text_props should correctly remove linked id' do
      data_hash = {}
      @content.remove_id_from_text_props(data_hash:, linked_id: @linked1.id)

      assert_equal("sdfadfa ksjdfksjbndfksdf <span class=\"dc--contentlink\" data-href=\"#{@linked2.id}\">sdfadfa</span>", data_hash['description'])
      assert_equal('Testtext', data_hash['text'])
      assert_equal(@content.text_with_linked_property_names, data_hash.keys)
    end

    test 'remove_id_from_text_props should correctly remove linked id from given keys' do
      data_hash = {}
      @content.remove_id_from_text_props(data_hash:, linked_id: @linked1.id, keys: ['text'])

      assert_nil(data_hash['description'])
      assert_equal('Testtext', data_hash['text'])
      assert_equal(['text'], data_hash.keys)
    end

    test 'RemoveContentReferencesFromTextJob should correctly remove linked id texts' do
      DataCycleCore::RemoveContentReferencesFromTextJob.perform_now(@linked1.id, [@content.id])

      assert_equal("sdfadfa ksjdfksjbndfksdf <span class=\"dc--contentlink\" data-href=\"#{@linked2.id}\">sdfadfa</span>", @content.description)
      assert_equal('Testtext', @content.text)
    end

    test 'destroying linked content should correctly remove linked id texts' do
      @linked1.destroy

      assert_equal("sdfadfa ksjdfksjbndfksdf <span class=\"dc--contentlink\" data-href=\"#{@linked2.id}\">sdfadfa</span>", @content.description)
      assert_equal('Testtext', @content.text)
    end
  end
end
