# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DataHashHelperTest < ActionView::TestCase
    include DataCycleCore::DataHashHelper
    include DataCycleCore::UiLocaleHelper

    def current_user = nil
    def attribute_editable?(*_args) = true

    test 'to_html_string wraps title and text in span and bold tags' do
      assert_equal '<span>Title: </span><b>Text</b>', to_html_string('Title', 'Text')
    end

    test 'to_html_string omits the colon when there is no text' do
      assert_equal '<span>Title</span><b></b>', to_html_string('Title')
    end

    test 'to_html_string handles a blank title' do
      assert_equal '<span></span><b></b>', to_html_string('')
    end

    test 'to_html_string keeps breadcrumb icons hidden from screen readers' do
      html = to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>Edit")

      assert_includes html, 'aria-hidden="true"'
      assert_includes html, 'class="fa fa-pencil"'
    end

    test 'to_html_string drops every tag but the icon' do
      assert_equal '<span>alert(1)</span><b></b>', to_html_string('<script>alert(1)</script>')
    end

    test 'object_from_definition returns nil for a blank definition or missing template_name' do
      assert_nil object_from_definition(nil)
      assert_nil object_from_definition({})
      assert_nil object_from_definition({ 'type' => 'object' })
    end

    test 'object_from_definition builds an unpersisted Thing for the given template_name' do
      object = object_from_definition({ 'template_name' => 'Artikel' })

      assert_kind_of DataCycleCore::Thing, object
      assert_equal 'Artikel', object.template_name
      assert_predicate object, :new_record?
    end

    test 'add_attribute_config copies a plain property under its key' do
      ordered_props = {}
      prop = { 'type' => 'string', 'sorting' => 1 }

      add_attribute_config('name', prop, :edit, 'content', ordered_props)

      assert_equal prop, ordered_props['name']
    end

    test 'add_attribute_config groups properties that declare an attribute_group' do
      ordered_props = {}
      prop = { 'type' => 'string', 'sorting' => 1, 'ui' => { 'attribute_group' => 'Address _collapsible' } }

      add_attribute_config('street', prop, :edit, 'content', ordered_props)

      assert_equal ['Address'], ordered_props.keys.map(&:strip)
      group = ordered_props.values.first

      assert_equal 'attribute_group', group['type']
      assert group['properties'].key?('street')
      assert_equal({ 'collapsible' => true }, group['features'])
    end

    test 'ordered_validation_properties returns nil without properties' do
      assert_nil ordered_validation_properties(validation: nil)
      assert_nil ordered_validation_properties(validation: { 'properties' => {} })
    end

    test 'ordered_validation_properties orders by sorting and skips internal properties' do
      validation = {
        'properties' => {
          'second' => { 'type' => 'string', 'sorting' => 2 },
          'first' => { 'type' => 'string', 'sorting' => 1 },
          'id' => { 'type' => 'string', 'sorting' => 0 }
        }
      }

      assert_equal ['first', 'second'], ordered_validation_properties(validation:).keys
    end

    test 'ordered_validation_properties applies the whitelist, blacklist and type filters' do
      validation = {
        'properties' => {
          'name' => { 'type' => 'string', 'sorting' => 1 },
          'count' => { 'type' => 'number', 'sorting' => 2 }
        }
      }

      assert_equal ['name'], ordered_validation_properties(validation:, whitelist_keys: ['name']).keys
      assert_equal ['count'], ordered_validation_properties(validation:, exclude_keys: ['name']).keys
      assert_equal ['name'], ordered_validation_properties(validation:, exclude_types: ['number']).keys
      assert_equal ['count'], ordered_validation_properties(validation:, type: 'number').keys
    end

    test 'attribute_group_title returns nil when no label translation exists' do
      I18n.stub(:exists?, false) do
        assert_nil attribute_group_title(struct_double(template_name: 'POI'), struct_double(attribute_name_from_key: 'nope'))
      end
    end

    test 'attribute_group_title renders the specific label when present' do
      stub(:render, '') do
        I18n.stub(:exists?, true) do
          html = attribute_group_title(struct_double(template_name: 'POI'), struct_double(attribute_name_from_key: 'address'))

          assert_includes html.to_s, 'key-address'
        end
      end
    end

    test 'attribute_group_title falls back to the generic attribute label' do
      generic = 'attribute_labels.address'

      stub(:render, '') do
        I18n.stub(:exists?, ->(*args, **_kw) { args.first.to_s == generic }) do
          html = attribute_group_title(struct_double(template_name: 'POI'), struct_double(attribute_name_from_key: 'address'))

          assert_includes html.to_s, 'key-address'
        end
      end
    end

    test 'keys_for_definition flattens an attribute group into its property keys' do
      definition = { 'type' => 'attribute_group', 'properties' => { 'street' => { 'type' => 'string' } } }

      assert_equal ['street'], keys_for_definition(nil, struct_double(attribute_name_from_key: 'address'), definition)
    end
  end
end
