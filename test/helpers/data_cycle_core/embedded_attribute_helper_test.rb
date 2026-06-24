# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class EmbeddedAttributeHelperTest < ActionView::TestCase
    include DataCycleCore::EmbeddedAttributeHelper

    test 'embedded_viewer_html_classes returns the static wrapper classes' do
      assert_equal 'detail-type embedded-viewer embedded-wrapper', embedded_viewer_html_classes
      assert_equal 'detail-type embedded-viewer embedded-wrapper', embedded_viewer_html_classes(key: 'anything')
    end

    test 'parsed_allowed_locales defaults to all available locales' do
      assert_equal I18n.available_locales, parsed_allowed_locales
      assert_equal I18n.available_locales, parsed_allowed_locales({})
    end

    test 'parsed_allowed_locales uses the configured allowed locales when present' do
      assert_equal [:de], parsed_allowed_locales({ parameters: { allowed_locales: ['de'] } })
    end
  end
end
