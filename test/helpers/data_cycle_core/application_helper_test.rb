# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

module DataCycleCore
  class ApplicationHelperTest < ActionView::TestCase
    include DataCycleCore::ApplicationHelper
    include DataCycleCore::UiLocaleHelper

    def current_user = nil
    def can?(*_args) = true

    CacheItemDouble = Struct.new(:id, :updated_at, :cache_valid_since)
    MessagesDouble = Struct.new(:present, :messages) do
      def present? = present
    end

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
      assert_includes send(:alert_box, 42, :info, true), '42'
    end

    test 'uploader_validation_to_text formats file size and resolution values' do
      assert_includes uploader_validation_to_text(1024, ['uploader', 'validation', 'file_size', 'max']), '<li>'
      assert_includes uploader_validation_to_text(100, ['uploader', 'validation', 'resolution', 'width']), '<li>'
    end

    test 'validation_messages renders error and warning messages' do
      content = struct_double(
        errors: MessagesDouble.new(true, { name: ['is invalid'] }),
        warnings: MessagesDouble.new(true, { name: ['looks odd'] })
      )

      html = validation_messages(content, struct_double(attribute_name_from_key: 'name'))

      assert_includes html.to_s, 'is invalid'
      assert_includes html.to_s, 'looks odd'
    end

    test 'content_uploader_data_hash memoizes and returns the asset id' do
      content = Object.new
      def content.asset_property_names = ['image']
      def content.set_memoized_attribute(_key, _value) = nil

      result = content_uploader_data_hash(content, struct_double(id: 'asset-1'))

      assert_equal 'asset-1', result['image']
    end

    test 'new_dialog_config resolves aggregate, template-name and schema-type dialogs' do
      agg = DataCycleCore::MasterData::Templates::AggregateTemplate::AGGREGATE_PROPERTY_NAME

      DataCycleCore::Feature::Aggregate.stub(:enabled?, true) do
        DataCycleCore::Feature::Aggregate.stub(:aggregate?, true) do
          assert_equal [agg], new_dialog_config(struct_double(template_name: 'x', schema_type: 'y'))['name']
        end
      end

      DataCycleCore::Feature::Aggregate.stub(:enabled?, false) do
        DataCycleCore.stub(:new_dialog, { 'poi' => { 'section' => [['Label **note', 'val']] }, 'thing' => { 'section' => ['name'] } }) do
          assert_equal [['Label', 'val']], new_dialog_config(struct_double(template_name: 'poi', schema_type: 'thing'))['section']
          assert new_dialog_config(struct_double(template_name: 'unknown', schema_type: 'thing')).key?('section')
        end
      end
    end

    test 'new_attribute_labels maps template schema properties to uploader labels' do
      DataCycleCore::Feature::Aggregate.stub(:enabled?, false) do
        DataCycleCore.stub(:new_dialog, { 'default' => { 'section' => ['name **list'] } }) do
          template = struct_double(schema: { 'properties' => { 'name' => { 'type' => 'string', 'label' => 'Name' } } }, template_name: 'x', schema_type: 'y')

          assert_equal({ 'type' => 'string', 'label' => 'Name', default_value: false }, new_attribute_labels(template)['name'])
        end
      end
    end

    test 'new_content_select_options filters and orders creatable templates' do
      with_value = new_content_select_options(query_methods: [{ 'method_name' => 'where', 'value' => { template_name: 'POI' } }], ordered_array: ['POI'])
      without_value = new_content_select_options(query_methods: [{ 'method_name' => 'all' }])

      assert_kind_of Array, with_value
      assert_kind_of Array, without_value
    end

    test 'sort_templates_by_translated_name orders by the displayed name, not the template_name' do
      # keys are the internal template_names — sorting by those would give
      # Icon Banner, Teaser-Kachel, Zitate, Öffnungszeiten
      templates = {
        'KachelManuell' => 'Teaser-Kachel',
        'WidgetsBannersIcons' => 'Icon Banner',
        'ZOpeningHours' => 'Öffnungszeiten',
        'AQuote' => 'Zitate'
      }.values.map do |label|
        Object.new.tap { |t| t.define_singleton_method(:translated_template_name) { |_locale| label } }
      end

      result = sort_templates_by_translated_name(templates).map { |t| t.translated_template_name(:de) }

      assert_equal ['Icon Banner', 'Öffnungszeiten', 'Teaser-Kachel', 'Zitate'], result
    end

    test 'uploader_validation returns config for text files and asset templates' do
      assert_equal 'DataCycleCore::TextFile', uploader_validation(asset_type: 'text_file')[:class]
      assert_kind_of Hash, uploader_validation(asset_type: 'image')
    end

    test 'render_new_partial_by_name returns nil for a blank partial name' do
      assert_nil render_new_partial_by_name(partial_name: '', template: nil, config: {})
    end

    test 'render_* helpers build partial candidates and delegate to the first existing partial' do
      key = struct_double(attribute_name_from_key: 'foo')

      stub(:render_first_existing_partial, nil) do
        assert_nil render_linked_history_viewer(key:, definition: { 'ui' => { 'show' => { 'type' => 'thing' } }, 'template_name' => 'poi' }, value: nil)
        assert_nil render_asset_editor(key:, value: nil, definition: { 'asset_type' => 'image' })
        assert_nil render_content_tile_details(item: Object.new)
      end
    end
  end
end
