# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

module DataCycleCore
  class ApplicationHelperTest < ActionView::TestCase
    include DataCycleCore::ApplicationHelper
    include DataCycleCore::UiLocaleHelper

    CacheItemDouble = Struct.new(:id, :updated_at, :cache_valid_since)

    test 'valid_mode normalizes unknown modes to grid' do
      assert_equal 'list', valid_mode('list')
      assert_equal 'tree', valid_mode('tree')
      assert_equal 'map', valid_mode('map')
      assert_equal 'grid', valid_mode('grid')
      assert_equal 'grid', valid_mode('something')
    end

    test 'schema_path_from_key extracts the bracketed path segments' do
      assert_equal ['a', 'b'], schema_path_from_key('datahash[a][b]')
    end

    test 'content_view_cache_key combines the item identity and the view mode' do
      key = content_view_cache_key(item: CacheItemDouble.new('x', nil, nil), mode: 'grid', watch_list: nil)

      assert_includes key, '_x_'
      assert_includes key, 'grid'
    end

    test 'to_query_params serializes nested values' do
      assert_equal({}, to_query_params(nil))
      assert_equal({ 'a' => 'b' }, to_query_params({ 'a' => 'b' }))
      # OpenStruct is intentional: to_query_params has a dedicated OpenStruct branch
      assert_equal({ 'a' => { attributes: { x: 1 }, class: 'OpenStruct' } }, to_query_params({ 'a' => OpenStruct.new(x: 1) })) # rubocop:disable Style/OpenStructUse
      assert_equal({ 'a' => { 'b' => 'c' } }, to_query_params({ 'a' => { 'b' => 'c' } }))
    end

    test 'attribute_label_for_uploader builds the uploader label hash' do
      assert_equal({ 'name' => { 'type' => 'string', 'label' => 'Name', default_value: false } }, attribute_label_for_uploader('name', { 'type' => 'string', 'label' => 'Name' }))
      assert_equal({ 'a' => { 'type' => 'string', default_value: false } }, attribute_label_for_uploader('obj', { 'type' => 'object', 'properties' => { 'a' => { 'type' => 'string' } } }))
    end

    test 'uploader_validation_to_text renders list items' do
      assert_includes uploader_validation_to_text('val', ['scope', 'leaf']), '<li>'
      assert_includes uploader_validation_to_text({ 'leaf' => 'val' }), '<li>'
    end

    test 'link_to_condition links or wraps in a span' do
      assert_includes link_to_condition(false, 'text'), '<span>text</span>'
      link = link_to_condition(true, 'text', '/path')

      assert_includes link, '<a'
      assert_includes link, '/path'
    end

    test 'conditional_tag wraps the block only when the condition is true' do
      assert_equal '<div>x</div>', conditional_tag(:div, true) { 'x' }
      assert_equal 'x', conditional_tag(:div, false) { 'x' }
    end

    test 'result_count formats classification counts and content counts' do
      assert_equal '5', result_count('classification_alias', 5, 'thing')
      assert_equal '-', result_count('classification_alias', 0, 'thing')
      assert_predicate result_count('grid', 3, 'thing'), :present?
    end

    test 'mode_icon returns an icon per mode and nil otherwise' do
      assert_includes mode_icon('grid'), 'fa-th'
      assert_includes mode_icon('list'), 'fa-th-list'
      assert_includes mode_icon('tree'), 'fa-sitemap'
      assert_includes mode_icon('map'), 'fa-map'
      assert_nil mode_icon('unknown')
    end

    test 'data_link_permission_icon maps permissions to icons' do
      assert_includes data_link_permission_icon('download'), 'fa-download'
      assert_includes data_link_permission_icon('read'), 'fa-eye'
      assert_includes data_link_permission_icon('write'), 'fa-pencil'
    end

    test 'dashboard_title and full_title return localized titles' do
      assert_predicate dashboard_title, :present?
      assert_predicate full_title, :html_safe?
    end

    test 'header_title renders a title span' do
      assert_includes header_title, 'class="title"'
    end

    test 'ice_cube_select_options lists the schedule rule types' do
      assert_kind_of Array, ice_cube_select_options
      assert_not_empty ice_cube_select_options
    end

    test 'content_uploader_data_hash is empty without an asset or asset property' do
      assert_equal({}, content_uploader_data_hash(nil, nil))
      assert_equal({}, content_uploader_data_hash(struct_double(asset_property_names: []), struct_double(id: 'a')))
    end

    test 'alert_box renders a notification div with the formatted message' do
      assert_includes send(:alert_box, 'message', :info, true), 'message'
      assert_includes send(:alert_box, { 'errors' => ['x'] }, :alert, false), 'Errors: x'
      assert_includes send(:alert_box, ['a', 'b'], :info, false), 'a&lt;br&gt;b'
    end
  end
end
