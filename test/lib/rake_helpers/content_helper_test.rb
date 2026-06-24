# frozen_string_literal: true

require 'test_helper'
require 'rake_helpers/content_helper'

module DataCycleCore
  # Named RakeContentHelperTest (not ContentHelperTest) to avoid a constant clash
  # with the view-helper test DataCycleCore::ContentHelperTest in test/helpers/.
  # This exercises the rake helper ::ContentHelper (require'd above).
  class RakeContentHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'find_or_create_content creates a new content when none exists' do
      content = ::ContentHelper.find_or_create_content(
        external_source: nil,
        external_key: 'content-helper-test-1',
        template_name: 'POI',
        data: { name: 'Content Helper POI' }
      )

      assert_predicate content, :persisted?
      assert_equal 'POI', content.template_name
      assert_equal 'content-helper-test-1', content.external_key
      assert_equal 'Content Helper POI', content.name
    end

    test 'find_or_create_content returns the existing content on a second call' do
      first = ::ContentHelper.find_or_create_content(
        external_source: nil,
        external_key: 'content-helper-test-2',
        template_name: 'POI',
        data: { name: 'Existing POI' }
      )

      second = ::ContentHelper.find_or_create_content(
        external_source: nil,
        external_key: 'content-helper-test-2',
        template_name: 'POI',
        data: { name: 'Should be ignored' }
      )

      assert_equal first.id, second.id
    end
  end
end
