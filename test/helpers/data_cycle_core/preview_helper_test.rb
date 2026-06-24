# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class PreviewHelperTest < ActionView::TestCase
    include DataCycleCore::PreviewHelper

    test 'preview_icon maps known keywords to their font-awesome icon' do
      assert_equal '<i class="fa fa-list"></i>', preview_icon('content_list')
      assert_equal '<i class="fa fa-map"></i>', preview_icon('detail_map')
      assert_equal '<i class="fa fa-calendar"></i>', preview_icon('event_overview')
      assert_equal '<i class="fa fa-picture-o"></i>', preview_icon('image_gallery')
    end

    test 'preview_icon falls back to the columns icon for unknown keys' do
      assert_equal '<i class="fa fa-columns"></i>', preview_icon('something_else')
    end

    test 'preview_icon returns an html-safe string' do
      assert_predicate preview_icon('list'), :html_safe?
    end
  end
end
