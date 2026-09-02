# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DownloadHelpersTest < ActionView::TestCase
    include DataCycleCore::DownloadHelpers
    include DataCycleCore::UiLocaleHelper

    test 'available_locales_for_select returns all locales when the content has none' do
      result = available_locales_for_select(struct_double(translated_locales: nil))

      assert_equal [:de, :en], result.values.sort
      assert_equal :de, result['Deutsch']
    end

    test 'available_locales_for_select restricts to the translated locales of the content' do
      result = available_locales_for_select(struct_double(translated_locales: ['de']))

      assert_equal [:de], result.values
      assert_equal :de, result['Deutsch']
    end

    test 'available_download_serializers delegates to the download feature' do
      DataCycleCore::Feature::Download.stub(:enabled_serializers_for_download, ['xml']) do
        assert_equal ['xml'], available_download_serializers(Object.new)
        assert_equal ['xml'], available_download_serializers(Object.new, [:embedded])
      end
    end
  end
end
