# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ThingHelperTest < ActionView::TestCase
    include DataCycleCore::ThingHelper
    include DataCycleCore::UiLocaleHelper

    ContentWarningDouble = Struct.new(:hard, :soft, :highlight_hard, :highlight_soft) do
      def hard_content_warnings? = hard
      def soft_content_warnings? = soft
      def highlight_hard_content_warnings? = highlight_hard
      def highlight_soft_content_warnings? = highlight_soft
    end

    test 'content_warning_class is empty without any warnings' do
      assert_equal '', content_warning_class(ContentWarningDouble.new(false, false, false, false))
    end

    test 'content_warning_class flags hard warnings as an alert' do
      assert_equal 'content-alert alert', content_warning_class(ContentWarningDouble.new(true, false, false, false))
    end

    test 'content_warning_class flags soft warnings as a warning' do
      assert_equal 'content-warning warning', content_warning_class(ContentWarningDouble.new(false, true, false, false))
    end

    test 'content_warning_class merges highlight classes and removes duplicates' do
      assert_equal 'content-alert alert hard-highlight', content_warning_class(ContentWarningDouble.new(true, false, true, false))
    end

    test 'content_tile_class returns the base classes for a nil content' do
      assert_equal 'grid-item data-cycle-object', content_tile_class(nil)
      assert_equal 'list-item data-cycle-object', content_tile_class(nil, 'list')
    end

    test 'async_thing_select_options returns an empty select for a blank value' do
      assert_equal '', async_thing_select_options(nil)
    end

    test 'async_thing_select_options renders a selected option per content' do
      thing = struct_double(id: 'uuid-1', template_name: 'Artikel', translated_locales: ['de'], schema_type: 'Article', first_available_locale: :de, title: 'Hello')

      html = async_thing_select_options(thing)

      assert_includes html, 'value="uuid-1"'
      assert_includes html, 'Hello (de)'
      assert_includes html, 'selected'
    end
  end
end
