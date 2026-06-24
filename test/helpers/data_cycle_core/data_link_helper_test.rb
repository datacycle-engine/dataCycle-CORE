# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DataLinkHelperTest < ActionView::TestCase
    include DataCycleCore::DataLinkHelper
    include DataCycleCore::UiLocaleHelper

    test 'finalize_agbs_label renders a finalize span when there is no agbs translation' do
      html = finalize_agbs_label

      assert_includes html, 'Bearbeitung final abschließen'
      assert_includes html, 'data-dc-tooltip'
      assert_predicate html, :html_safe?
    end

    test 'terms_of_use_label returns html-safe content' do
      html = terms_of_use_label

      assert_predicate html, :html_safe?
      assert_predicate html, :present?
    end

    test 'download_item_type renders the type and title for a non-thing item' do
      data_link = struct_double(item: DataCycleCore::WatchList.new(name: 'My List'))
      html = download_item_type(data_link)

      assert_includes html, 'My List'
      assert_includes html, 'item-title'
    end
  end
end
