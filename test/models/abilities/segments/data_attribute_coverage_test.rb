# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the DataAttribute ability segment - the per-attribute predicate
  # matchers (pure logic over an attribute's definition/content/key/options) and the
  # to_restrictions translation dispatch. No DB content is needed: the attribute and
  # its content are lightweight doubles; only ExternalSystem.by_names_or_identifiers
  # touches the (empty) DB in one to_restrictions branch.
  class DataAttributeSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # Builds a plain object whose given methods return the given values; a Proc value
    # is installed as the method body so doubles can accept arguments (concept_scheme).
    def make_double(methods)
      obj = Object.new
      methods.each do |name, val|
        if val.is_a?(Proc)
          obj.define_singleton_method(name, &val)
        else
          obj.define_singleton_method(name) { val }
        end
      end
      obj
    end

    def attr_dbl(definition: {}, content: nil, scope: :show, key: 'name', options: {})
      struct_double(definition:, content:, scope:, key:, options:)
    end

    def segment(method_names = [], except_list = {})
      # captured as a local: a Proc double body runs with self bound to the double,
      # so the value has to be built outside and closed over.
      scheme = make_double(external_source_id: 'ext-1')
      seg = DataCycleCore::Abilities::Segments::DataAttribute.new(method_names, except_list)
      seg.ability = make_double(
        user: make_double(id: 'user-1', ui_locale: :de),
        session: nil,
        concept_scheme: ->(_tree_label) { scheme }
      )
      seg
    end

    test 'aggregate-override predicates read the definition' do
      seg = segment
      on = attr_dbl(definition: { 'features' => { 'aggregate' => { 'aggregate_for' => 'x' } } })
      off = attr_dbl(definition: {})

      assert seg.attribute_aggregate_override?(on)
      assert_not seg.attribute_aggregate_override?(off)
      assert seg.attribute_not_aggregate_override?(off)
      assert_not seg.attribute_not_aggregate_override?(on)
    end

    test 'content external predicates delegate to content.external?' do
      seg = segment
      ext = attr_dbl(content: make_double(external?: true))
      int = attr_dbl(content: make_double(external?: false))

      assert seg.attribute_content_external?(ext)
      assert_not seg.attribute_content_external?(int)
      assert seg.attribute_content_not_external?(int)
      assert_not seg.attribute_content_not_external?(ext)
    end

    test 'attribute_force_render? reads the force_render option as a string' do
      seg = segment

      assert seg.attribute_force_render?(attr_dbl(options: { 'force_render' => 'true' }))
      assert_not seg.attribute_force_render?(attr_dbl(options: {}))
    end

    test 'attribute_tree_label_visible? compares the tree-label external source to the content' do
      seg = segment
      match = attr_dbl(definition: { 'tree_label' => 'Keywords' }, content: make_double(external_source_id: 'ext-1'))
      mismatch = attr_dbl(definition: { 'tree_label' => 'Keywords' }, content: make_double(external_source_id: 'other'))

      assert seg.attribute_tree_label_visible?(match)
      assert_not seg.attribute_tree_label_visible?(mismatch)
    end

    test 'template and attribute (and-template) whitelist predicates' do
      seg = segment
      a = attr_dbl(content: make_double(template_name: 'Artikel'), key: 'name')

      assert seg.template_whitelisted?(a, ['Artikel'])
      assert_not seg.template_whitelisted?(a, ['POI'])
      assert_not seg.template_not_blacklisted?(a, ['Artikel'])
      assert seg.template_not_blacklisted?(a, ['POI'])

      assert seg.attribute_whitelisted?(a, [['name']])
      assert_not seg.attribute_whitelisted?(a, [['other']])
      assert_not seg.attribute_not_blacklisted?(a, [['name']])
      assert seg.attribute_not_blacklisted?(a, [['other']])

      assert seg.attribute_and_template_whitelisted?(a, { 'Artikel' => ['name'] })
      assert_not seg.attribute_and_template_whitelisted?(a, { 'Artikel' => ['other'] })
      assert seg.attribute_and_template_not_blacklisted?(a, { 'Artikel' => ['other'] })
      assert_not seg.attribute_and_template_not_blacklisted?(a, { 'Artikel' => ['name'] })

      # except_list is empty on the default segment -> nothing is excluded
      assert seg.attribute_not_excluded?(a)
    end

    test 'attribute type whitelist predicates read definition type' do
      seg = segment
      t = attr_dbl(definition: { 'type' => 'image' })

      assert seg.attribute_type_whitelisted?(t, ['image'])
      assert_not seg.attribute_type_whitelisted?(t, ['string'])
      assert seg.attribute_type_not_blacklisted?(t, ['string'])
      assert_not seg.attribute_type_not_blacklisted?(t, ['image'])
    end

    test 'content_created_by_user? compares content.created_by to the current user id' do
      seg = segment

      assert seg.content_created_by_user?(attr_dbl(content: make_double(created_by: 'user-1')))
      assert_not seg.content_created_by_user?(attr_dbl(content: make_double(created_by: 'someone-else')))
    end

    test 'attribute value present/blank predicates read the keyed value off the content' do
      seg = segment
      present = attr_dbl(content: make_double(name: 'hello'), key: 'name')
      blank = attr_dbl(content: make_double(name: ''), key: 'name')

      assert seg.attribute_value_present?(present)
      assert_not seg.attribute_value_present?(blank)
      assert seg.attribute_value_blank?(blank)
      assert_not seg.attribute_value_blank?(present)
    end

    test 'attribute_content_not_external_source? matches name or identifier of the source' do
      seg = segment
      from_feratel = attr_dbl(content: make_double(external_source: struct_double(name: 'feratel', identifier: 'feratel-id')))
      no_source = attr_dbl(content: make_double(external_source: nil))

      assert_not seg.attribute_content_not_external_source?(from_feratel, ['feratel'])
      assert_not seg.attribute_content_not_external_source?(from_feratel, ['feratel-id'])
      assert seg.attribute_content_not_external_source?(from_feratel, ['other'])
      assert seg.attribute_content_not_external_source?(no_source, ['feratel'])
    end

    test 'to_restrictions builds one translation entry per configured method name' do
      methods = [
        ['attribute_not_excluded?'],
        ['template_whitelisted?', ['Artikel']],
        ['attribute_whitelisted?', [['name']]],
        ['attribute_and_template_whitelisted?', { 'Artikel' => ['name'] }],
        ['attribute_type_whitelisted?', ['image']],
        ['attribute_content_not_external_source?', ['feratel']]
      ]
      seg = segment(methods, { 'Artikel' => ['name'] })

      result = nil
      assert_nothing_raised { result = seg.to_restrictions }
      assert_kind_of Array, result
      assert_equal methods.size, result.size
    end
  end
end
