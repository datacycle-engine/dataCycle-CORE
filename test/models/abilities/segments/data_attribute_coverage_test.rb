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

    def segment(method_names = [], except_list = {}, klass = DataCycleCore::Abilities::Segments::DataAttribute)
      # captured as a local: a Proc double body runs with self bound to the double,
      # so the value has to be built outside and closed over.
      scheme = make_double(external_source_id: 'ext-1')
      seg = klass.new(method_names, except_list)
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

    test 'attribute_tree_label_visible? is always true for global, local, or tree-label-less attributes' do
      seg = segment
      # a content whose external source would NOT match the tree-label source (ability.concept_scheme -> 'ext-1'),
      # so visibility can only come from the global/local short-circuits.
      mismatched = make_double(external_source_id: 'other')

      assert seg.attribute_tree_label_visible?(attr_dbl(definition: { 'global' => true, 'tree_label' => 'Keywords' }, content: mismatched))
      assert seg.attribute_tree_label_visible?(attr_dbl(definition: { 'local' => true, 'tree_label' => 'Keywords' }, content: mismatched))
      # non-classification attributes have no tree_label -> always visible (content is never consulted)
      assert seg.attribute_tree_label_visible?(attr_dbl(definition: {}))
    end

    # Import & edit control editability gate for Redmine #49247: `external` attributes are
    # not manually editable, while `global`/`local` always are. Wired into every role config
    # (config/configurations/permissions/roles/*.yml) via :attribute_not_external?.
    test 'attribute_not_external? (DataAttribute) blocks external-only attributes, allows global/local/plain' do
      seg = segment

      assert seg.attribute_not_external?(attr_dbl(definition: {})), 'plain attribute is editable'
      assert seg.attribute_not_external?(attr_dbl(definition: { 'external' => false })), 'external:false is editable'
      assert seg.attribute_not_external?(attr_dbl(definition: { 'global' => true })), 'global is editable'
      assert seg.attribute_not_external?(attr_dbl(definition: { 'local' => true })), 'local is editable'
      # global/local win over external
      assert seg.attribute_not_external?(attr_dbl(definition: { 'external' => true, 'global' => true })), 'global overrides external'
      # external-only attributes can not be manually edited
      assert_not seg.attribute_not_external?(attr_dbl(definition: { 'external' => true })), 'external-only is not editable'
    end

    test 'attribute_not_external? (DataAttributeAllowedForUpdate) also gates on content source and overlay' do
      seg = segment([], {}, DataCycleCore::Abilities::Segments::DataAttributeAllowedForUpdate)
      # A stateless double for external content. external? is stubbed false so attribute_is_in_overlay?
      # short-circuits before the real Feature::Overlay collaborator; the overlay branch below is
      # instead reached through overlay_attribute? (which reads the definition/properties_for).
      external_content = make_double(external_source_id: 'ext-1', external?: false, properties_for: ->(_key) {})

      # global/local are always editable, even on external content
      assert seg.attribute_not_external?(attr_dbl(definition: { 'global' => true }, content: external_content))
      assert seg.attribute_not_external?(attr_dbl(definition: { 'local' => true }, content: external_content))
      # locally created content (no external source) + non-external attribute -> editable
      assert seg.attribute_not_external?(attr_dbl(definition: {}, content: make_double(external_source_id: nil)))
      # external attribute on external content, not an overlay -> not editable
      assert_not seg.attribute_not_external?(attr_dbl(definition: { 'external' => true }, content: external_content))
      # ...unless it is an overlay attribute
      overlay_definition = { 'external' => true, 'features' => { 'overlay' => { 'overlay_for' => 'name' } } }

      assert seg.attribute_not_external?(attr_dbl(definition: overlay_definition, content: external_content))
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
