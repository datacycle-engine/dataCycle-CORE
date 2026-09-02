# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class RelatedComputedTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @organization = create_content('Organization', { name: 'Test Organisation 1' })
      @image = create_content('Bild', { name: 'Test Bild 1', author: [@organization.id] })
    end

    test 'update related content -> updates copyright_notice_computed' do
      assert_equal '(c) Test Organisation 1', @image.copyright_notice_computed

      @organization.set_data_hash(data_hash: { name: 'Test Organisation 2' })
      perform_enqueued_jobs

      assert_equal '(c) Test Organisation 2', @image.reload.copyright_notice_computed
    end

    test 'delete related content -> updates copyright_notice_computed' do
      assert_equal '(c) Test Organisation 1', @image.copyright_notice_computed

      @organization.destroy
      perform_enqueued_jobs

      assert_nil @image.reload.copyright_notice_computed
    end
  end
end
