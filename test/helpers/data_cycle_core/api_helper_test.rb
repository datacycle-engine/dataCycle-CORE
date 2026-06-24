# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ApiHelperTest < ActionView::TestCase
    include DataCycleCore::ApiHelper

    ContentDouble = Struct.new(:embedded, :translatable, :locale) do
      def embedded? = embedded
      def translatable? = translatable
      def first_available_locale = locale
    end

    test 'attribute_key camelizes the key when no api name is configured' do
      assert_equal 'myAttributeName', attribute_key('my_attribute_name', {})
    end

    test 'api_definition merges the versioned config and strips other versions' do
      @api_context = 'api'
      @api_version = 4

      assert_equal({ 'name' => 'x', 'disabled' => true }, api_definition({ 'api' => { 'name' => 'x', 'v4' => { 'disabled' => true } } }))
    end

    test 'api_definition returns an empty hash when the context is missing' do
      assert_equal({}, api_definition({ 'other' => {} }, 4, 'api'))
    end

    test 'attribute_disabled? reads the disabled flag from the api definition' do
      assert attribute_disabled?({ 'api' => { 'disabled' => true } }, 4, 'api')
      assert_not attribute_disabled?({ 'api' => {} }, 4, 'api')
    end

    test 'included_attribute? handles defaults, wildcards and explicit lists' do
      assert included_attribute?('@id', nil)
      assert_not included_attribute?('name', nil)
      assert included_attribute?('name', [['full', 'recursive']])
      assert included_attribute?('name', [['name'], ['other']], false)
      assert_not included_attribute?('missing', [['name']], false)
    end

    test 'fields_attribute? treats a wildcard as matching everything' do
      assert fields_attribute?('anything', [['*']])
      assert fields_attribute?('name', [['name']], false)
      assert_not fields_attribute?('missing', [['name']], false)
    end

    test 'included_attribute_not_full? excludes full recursive lists' do
      assert included_attribute_not_full?('name', [['name']])
      assert_not included_attribute_not_full?('name', [['full', 'recursive']])
    end

    test 'attribute_visible? combines include and fields lists' do
      assert attribute_visible?('@id', {})
      assert attribute_visible?('name', { include: [['name']] })
      assert attribute_visible?('whatever', { fields: [['*']] })
      assert_not attribute_visible?('missing', { include: [['name']], fields: [['other']] })
    end

    test 'subtree_for drops the matched prefix or returns the full list' do
      assert_equal [['b'], ['c']], subtree_for('a', [['a', 'b'], ['a', 'c'], ['x']])
      assert_equal [['full', 'recursive']], subtree_for('a', [['full', 'recursive']])
    end

    test 'attribute_wildcard? detects the star entry' do
      assert attribute_wildcard?([['*']])
      assert_not attribute_wildcard?([['name']])
      assert_nil attribute_wildcard?(nil)
    end

    test 'full_recursive? requires both full and recursive in the first entry' do
      assert full_recursive?([['full', 'recursive']])
      assert_not full_recursive?([['name']])
    end

    test 'inherit_options copies ancestor ids and languages' do
      result = inherit_options(nil, { ancestor_ids: [1], languages: ['de'] })

      assert_equal [1], result[:ancestor_ids]
      assert_equal ['de'], result[:languages]
    end

    test 'select_attributes returns the first element of each entry' do
      assert_equal ['a', 'c'], select_attributes([['a', 'b'], ['c']])
      assert_equal [], select_attributes(nil)
    end

    test 'serialize_language joins the languages with a comma' do
      assert_equal 'de,en', serialize_language(['de', 'en'])
    end

    test 'in_language? is true for translatable content or matching language' do
      assert in_language?(ContentDouble.new(false, true, :de), { languages: [] })
      assert in_language?(ContentDouble.new(false, false, :de), { languages: ['de'] })
      assert in_language?(ContentDouble.new(true, false, :en), { translatable_embedded: true, languages: [] })
      assert_not in_language?(ContentDouble.new(false, false, :de), { languages: ['en'] })
    end

    test 'api_value_format wraps the value with the configured prepend and append' do
      assert_equal 'x', api_value_format('x', nil)
      assert_equal 'x', api_value_format('x', {})
      assert_equal '<x>', api_value_format('x', { 'format' => { 'prepend' => '<', 'append' => '>' } })
      assert_equal '', api_value_format('', { 'format' => { 'prepend' => '<' } })
    end

    test 'merge_overlay merges overlay values and skips blanks' do
      assert_equal({ 'a' => '1' }, merge_overlay({}, { 'a' => '1', 'b' => nil }))
      assert_equal({ 'dc:classification' => ['x', 'y'] }, merge_overlay({ 'dc:classification' => ['x'] }, { 'dc:classification' => ['y'] }))
      assert_equal({}, merge_overlay({}, { 'a' => nil }))
    end

    test 'geoshape_as_json wraps polygons and lines and ignores other geometries' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      line = factory.line_string([factory.point(0, 0), factory.point(1, 1)])

      assert_nil geoshape_as_json(nil)
      assert_nil geoshape_as_json(factory.point(0, 0))
      assert_equal ['line'], geoshape_as_json(line).keys
    end

    test 'build_new_options_object returns the options unchanged for the graph attribute' do
      options = { fields: [], include: [], ancestor_ids: [], languages: [] }

      assert_equal options, build_new_options_object('@graph', options)
    end

    test 'build_new_options_object descends into a field-filtered subtree' do
      options = { fields: [['name', 'sub']], include: [], field_filter: true, ancestor_ids: [], languages: [] }
      result = build_new_options_object('name', options)

      assert_equal [['sub']], result[:fields]
      assert result[:field_filter]
    end

    test 'build_new_options_object falls back to the default attributes when not included' do
      options = { fields: [['name']], include: [['name']], field_filter: false, ancestor_ids: [], languages: [] }
      result = build_new_options_object('missing', options)

      assert_equal [['@id'], ['@type']], result[:fields]
      assert result[:field_filter]
    end

    test 'render_slugified_name slugifies a single language and is nil without languages' do
      assert_nil render_slugified_name(struct_double(name: 'Hello World'), [])
      assert_equal 'hello-world', render_slugified_name(struct_double(name: 'Hello World'), ['de'])
    end

    test 'render_slugified_name returns a localized array for multiple languages' do
      result = render_slugified_name(struct_double(name: 'Hello'), ['de', 'en'])

      assert_equal 2, result.size
      assert_equal({ '@language' => 'de', '@value' => 'hello' }, result.first)
    end

    test 'ordered_api_properties orders by sorting and skips internal properties' do
      validation = {
        'properties' => {
          'b' => { 'type' => 'string', 'sorting' => 2 },
          'a' => { 'type' => 'string', 'sorting' => 1 },
          'id' => { 'type' => 'string', 'sorting' => 0 }
        }
      }

      assert_equal ['a', 'b'], ordered_api_properties(validation:).map(&:first)
      assert_nil ordered_api_properties(validation: nil)
    end
  end
end
