# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class RelatedComputedTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @organization = DataCycleCore::TestPreparations
        .create_content(template_name: 'Organization', data_hash: { name: 'Test Organisation 1' })
      @image = DataCycleCore::TestPreparations
        .create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', author: [@organization.id] })
    end

    test 'update related content -> updates copyright_notice_computed' do
      assert_equal '(c) Test Organisation 1', @image.copyright_notice_computed

      @organization.set_data_hash(data_hash: { name: 'Test Organisation 2' })

      assert_equal '(c) Test Organisation 2', @image.reload.copyright_notice_computed
    end

    test 'delete related content -> updates copyright_notice_computed' do
      assert_equal '(c) Test Organisation 1', @image.copyright_notice_computed

      @organization.destroy

      assert_nil @image.reload.copyright_notice_computed
    end
  end
end
