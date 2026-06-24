# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class HistoryHelperTest < ActionView::TestCase
    include DataCycleCore::HistoryHelper
    include DataCycleCore::UiLocaleHelper

    HistoryDouble = Struct.new(:is_history, :thing) do
      def history? = is_history
    end

    test 'save_navigate digs into a nested hash along the path' do
      assert_equal 1, save_navigate({ 'a' => { 'b' => 1 } }, ['a', 'b'])
      assert_nil save_navigate({ 'a' => 1 }, ['a', 'b'])
      assert_nil save_navigate('scalar', ['a'])
    end

    test 'attribute_changes returns the diff only for responding keys' do
      assert_equal 1, attribute_changes(struct_double(name: 'v'), { 'name' => 1 }, 'name')
      assert_nil attribute_changes(Object.new, nil, 'name')
    end

    test 'changes_class returns the indicator class for a matching value' do
      assert_equal 'has-changes new', changes_class([['+', ['a', 'b']]], 'a')
      assert_equal '', changes_class([['~', ['x']]], 'a')
      assert_equal '', changes_class(nil, 'a')
    end

    test 'changes_mode derives the indicator from the diff shape' do
      assert_equal 'has-changes new', changes_mode(['+', ['a']])
      assert_equal 'has-changes edit', changes_mode([['x'], ['y']])
      assert_equal 'has-changes edit', changes_mode({ 'a' => 1 })
      assert_equal '', changes_mode(nil)
    end

    test 'changes_by_value returns the mode/value pair for a match' do
      assert_equal [['+', 'a']], changes_by_value([['+', ['a']]], 'a')
      assert_nil changes_by_value([['~', ['x']]], 'a')
    end

    test 'changes_by_mode and change_by_mode extract values for a mode' do
      assert_equal ['a', 'b'], changes_by_mode([['+', ['a', 'b']]], '+')
      assert_equal [], changes_by_mode([['~', ['x']]], '+')
      assert_equal 'x', change_by_mode(['+', 'x'], '+')
      assert_equal [], change_by_mode(['~', 'x'], '+')
    end

    test 'diff_target_id reads the id for non-history objects' do
      assert_equal 'x', diff_target_id(struct_double(id: 'x'))
    end

    test 'diff_target_by_key reads the attribute from the diff target' do
      assert_equal 'X', diff_target_by_key(key: 'name', diff_target: struct_double(name: 'X'))
      assert_nil diff_target_by_key(key: 'name', diff_target: nil)
    end

    test 'thing_from_histories orders left/right depending on history state' do
      assert_equal ['T', nil, false], thing_from_histories(struct_double(thing: 'T'), nil)
      left = HistoryDouble.new(true, nil)
      right = HistoryDouble.new(true, nil)

      assert_equal [left, right, false], thing_from_histories(left, right)
      plain_left = HistoryDouble.new(false, nil)
      plain_right = HistoryDouble.new(false, nil)

      assert_equal [plain_left, plain_right, true], thing_from_histories(plain_left, plain_right)
      hist = HistoryDouble.new(true, nil)
      plain = HistoryDouble.new(false, nil)

      assert_equal [plain, hist, true], thing_from_histories(hist, plain)
    end

    test 'publication_attribute_changes renders del/ins based on the change mode' do
      assert_includes publication_attribute_changes(['~', Date.new(2024, 1, 1), Date.new(2024, 2, 1)], nil), '<del>'
      assert_includes publication_attribute_changes(['~', Date.new(2024, 1, 1), Date.new(2024, 2, 1)], nil), '<ins>'
      assert_includes publication_attribute_changes(['+', Date.new(2024, 1, 1)], nil), '<ins>'
      assert_includes publication_attribute_changes(['-'], struct_double(publish_at: Time.zone.local(2024, 1, 1))), '<del>'
      assert_predicate publication_attribute_changes(nil, struct_double(publish_at: Time.zone.local(2024, 1, 1))), :present?
    end

    test 'history_by_link links to the user or falls back to System' do
      assert_includes history_by_link(nil), 'System'
      link = history_by_link(struct_double(full_name: 'John Doe', email: 'john@example.com'))

      assert_includes link, 'John Doe'
      assert_includes link, 'mailto:john@example.com'
    end

    test 'history_dropdown_link renders the user link or a System span' do
      assert_includes history_dropdown_link(nil), 'System'
      assert_includes history_dropdown_link(struct_double(full_name: 'John', email: 'j@x.com')), 'mailto:j@x.com'
    end

    test 'history_link_icon is nil without an icon and renders the icon class otherwise' do
      assert_nil history_link_icon(struct_double(icon: nil))
      assert_includes history_link_icon(struct_double(icon: { class: 'fa fa-arrows-h', tooltip: 'history.created' })), 'fa-arrows-h'
    end

    test 'version_name_html wraps the version name container' do
      assert_includes version_name_html(struct_double(version_name: nil, can_remove_version_name: false, id: 'x')), 'named-version-container'
    end

    test 'object_viewer_history_options computes the change mode' do
      result = object_viewer_history_options(object: struct_double(template_name: 'Artikel'), key: 'name', options: {}, item_diff: nil)

      assert_equal '', result[:mode]
    end

    test 'complete_history_list is empty for a nil content' do
      assert_equal [], complete_history_list(nil)
    end
  end
end
