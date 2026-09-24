# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class Schema
    # Tests the /schema detail-page presenters (#50201): FragmentReader reads OpenAPI
    # fragments into display descriptors, PropertyPresenter derives the dc flags from
    # the raw definition, and Document/TemplatePresenter stay congruent with the
    # generated components/schemas (the v4 truth — no divergent second logic).
    class PresenterTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # ---------------- FragmentReader (pure, no DB) ----------------

      test 'cardinality is :many for arrays and :one otherwise' do
        assert_equal :many, FragmentReader.cardinality({ 'type' => 'array', 'items' => {} })
        assert_equal :one, FragmentReader.cardinality({ 'type' => 'string' })
      end

      test 'scalar fragments map to schema.org literals via type + format' do
        assert_equal 'DateTime', FragmentReader.descriptors({ 'type' => 'string', 'format' => 'date-time' }).first[:label]
        assert_equal 'Date', FragmentReader.descriptors({ 'type' => 'string', 'format' => 'date' }).first[:label]
        assert_equal 'URL', FragmentReader.descriptors({ 'type' => 'string', 'format' => 'uri' }).first[:label]
        assert_equal 'Integer', FragmentReader.descriptors({ 'type' => 'integer' }).first[:label]
        assert_equal 'Number', FragmentReader.descriptors({ 'type' => 'number' }).first[:label]
        assert_equal 'Boolean', FragmentReader.descriptors({ 'type' => 'boolean' }).first[:label]
        assert_equal 'Text', FragmentReader.descriptors({ 'type' => 'string' }).first[:label]
      end

      test 'a scalar descriptor carries a schema.org href for the literal' do
        assert_equal '//schema.org/Text', FragmentReader.descriptors({ 'type' => 'string' }).first[:href]
      end

      test 'a blank fragment yields no descriptors' do
        assert_equal [], FragmentReader.descriptors({})
        assert_equal [], FragmentReader.descriptors({ 'oneOf' => [] })
      end

      test 'a linked oneOf drops the redundant generic reference wrapper and keeps the concrete template' do
        # EntityBuilder#linked_schema emits oneOf: [EntityReference, *template_refs] (see entity_builder.rb).
        fragment = {
          'type' => 'array',
          'items' => { 'oneOf' => [
            { '$ref' => '#/components/schemas/EntityReference' },
            { '$ref' => '#/components/schemas/Article' }
          ] }
        }
        descriptors = FragmentReader.descriptors(fragment, { 'Article' => 'Article' })

        assert_equal ['Article'], descriptors.pluck(:label), 'the generic EntityReference wrapper must be dropped'
        assert_equal 'Article', descriptors.first[:template]
      end

      test 'the generic reference wrapper is kept when it is the only descriptor' do
        fragment = { 'type' => 'array', 'items' => { 'oneOf' => [{ '$ref' => '#/components/schemas/EntityReference' }] } }

        assert_equal(['EntityReference'], FragmentReader.descriptors(fragment).pluck(:label))
      end

      test 'multiple generic reference wrappers all collapse once a concrete type is present' do
        fragment = {
          'type' => 'array',
          'items' => { 'oneOf' => [
            { '$ref' => '#/components/schemas/EntityReference' },
            { '$ref' => '#/components/schemas/CollectionReference' },
            { '$ref' => '#/components/schemas/Article' }
          ] }
        }
        descriptors = FragmentReader.descriptors(fragment, { 'Article' => 'Article' })

        assert_equal ['Article'], descriptors.pluck(:label), 'every generic wrapper is dropped when a concrete type exists'
      end

      test 'multiple generic reference wrappers all survive when nothing concrete accompanies them' do
        fragment = { 'oneOf' => [
          { '$ref' => '#/components/schemas/EntityReference' },
          { '$ref' => '#/components/schemas/CollectionReference' }
        ] }

        assert_equal ['EntityReference', 'CollectionReference'], FragmentReader.descriptors(fragment).pluck(:label),
                     'with nothing concrete to show, the generic wrappers must not all vanish'
      end

      test 'a kept generic reference envelope is a :reference chip with no routable template (no 404 link)' do
        # EntityReference/CollectionReference are not ThingTemplates — a template: here
        # would render a link to /schema/EntityReference (404) and the wrong icon.
        ['EntityReference', 'CollectionReference'].each do |name|
          descriptor = FragmentReader.descriptors({ '$ref' => "#/components/schemas/#{name}" }).first

          assert_equal name, descriptor[:label]
          assert_equal :reference, descriptor[:kind]
          assert_nil descriptor[:template], "#{name} must not be treated as a routable template"
        end
      end

      test 'every descriptor carries a semantic :kind so the stylesheet can colour the chip' do
        assert_equal :text, FragmentReader.descriptors({ 'type' => 'string' }).first[:kind]
        assert_equal :datetime, FragmentReader.descriptors({ 'type' => 'string', 'format' => 'date-time' }).first[:kind]
        assert_equal :concept, FragmentReader.descriptors({ '$ref' => '#/components/schemas/Concept' }).first[:kind]
        assert_equal :geo, FragmentReader.descriptors({ '$ref' => '#/components/schemas/GeoCoordinates' }).first[:kind]
        assert_equal :reference, FragmentReader.descriptors({ '$ref' => '#/components/schemas/FooBar' }, { 'FooBar' => 'Foo Bar' }).first[:kind]
      end

      test 'a $ref to a shared component renders as a shared type, not a template link' do
        concept = FragmentReader.descriptors({ '$ref' => '#/components/schemas/Concept' }).first

        assert_equal 'skos:Concept', concept[:label]
        assert_nil concept[:template]
      end

      test 'both geo shared components (GeoCoordinates, GeoShape) are classified as :geo' do
        FragmentReader::GEO_SHARED_NAMES.each do |name|
          descriptor = FragmentReader.descriptors({ '$ref' => "#/components/schemas/#{name}" }).first

          assert_equal name, descriptor[:label]
          assert_equal :geo, descriptor[:kind], "#{name} must be a :geo chip"
          assert_nil descriptor[:template], "#{name} is a shared type, not a routable template"
        end
      end

      test 'a non-geo shared component is classified as :shared' do
        # a shared name that is neither a geo type, the Concept special-case, nor a
        # generic reference envelope (those resolve to :geo/:concept/:reference first)
        # stays a neutral :shared chip.
        shared_name = (FragmentReader::SHARED_NAMES - FragmentReader::GEO_SHARED_NAMES -
          FragmentReader::GENERIC_REFERENCE_NAMES - ['Concept']).first
        skip 'no non-geo shared component configured' if shared_name.blank?

        descriptor = FragmentReader.descriptors({ '$ref' => "#/components/schemas/#{shared_name}" }).first

        assert_equal :shared, descriptor[:kind]
      end

      test 'a $ref to a template resolves to a routable :id via the template_index' do
        index = { 'FooBar' => 'Foo Bar' }
        descriptor = FragmentReader.descriptors({ '$ref' => '#/components/schemas/FooBar' }, index).first

        assert_equal 'Foo Bar', descriptor[:label]
        assert_equal 'Foo Bar', descriptor[:template]
      end

      test 'array items are unwrapped so descriptors describe the delivered element' do
        fragment = { 'type' => 'array', 'items' => { '$ref' => '#/components/schemas/Concept' } }

        assert_equal 'skos:Concept', FragmentReader.descriptors(fragment).first[:label]
      end

      test 'the translatable language-array branch is dropped from a oneOf' do
        fragment = {
          'oneOf' => [
            { 'type' => 'string' },
            { 'type' => 'array', 'items' => { 'properties' => { '@value' => {}, '@language' => {} } } }
          ]
        }
        descriptors = FragmentReader.descriptors(fragment)

        assert_equal 1, descriptors.size
        assert_equal 'Text', descriptors.first[:label]
      end

      # ---------------- PropertyPresenter flags (from the raw definition) ----------------

      test 'flags are derived from the raw property definition' do
        definition = {
          'type' => 'classification', 'storage_location' => 'translated_value',
          'search' => true, 'features' => { 'overlay' => { 'overlay_for' => 'x' } }
        }
        flags = PropertyPresenter.new(api_name: 'x', fragment: {}, definition:).flags

        assert flags[:translated]
        assert flags[:classification]
        assert flags[:fulltext]
        assert flags[:overlay]
        assert_not flags[:embedded]
      end

      test 'a property without a raw definition (envelope key) has no flags set' do
        flags = PropertyPresenter.new(api_name: '@type', fragment: { 'type' => 'array' }).flags

        assert_equal [], flags.select { |_, v| v }.keys
      end

      test 'the geographic flag comes from the raw definition type, the linked flag likewise' do
        geo = PropertyPresenter.new(api_name: 'x', fragment: {}, definition: { 'type' => 'geographic' }).flags
        linked = PropertyPresenter.new(api_name: 'x', fragment: {}, definition: { 'type' => 'linked' }).flags

        assert geo[:geographic]
        assert_not geo[:linked]
        assert linked[:linked]
        assert_not linked[:geographic]
      end

      test 'to_h exposes the full presenter contract (the keys the index reuses)' do
        contract = PropertyPresenter.new(api_name: 'contentLocation', fragment: { 'type' => 'string' }, definition: {}).to_h

        assert_equal [:api_name, :label, :expected_type, :cardinality, :flags, :classification_tree, :target_templates].sort,
                     contract.keys.sort
        assert_equal 'contentLocation', contract[:api_name]
        assert_equal :one, contract[:cardinality]
      end

      test 'label uses the fragment title and falls back to the api_name' do
        assert_equal 'Ort', PropertyPresenter.new(api_name: 'contentLocation', fragment: { 'title' => 'Ort' }).label
        assert_equal 'contentLocation', PropertyPresenter.new(api_name: 'contentLocation', fragment: {}).label
      end

      test 'target_templates lists only the routable ids of resolved template refs' do
        fragment = {
          'type' => 'array',
          'items' => { 'oneOf' => [
            { '$ref' => '#/components/schemas/EntityReference' },
            { '$ref' => '#/components/schemas/Article' }
          ] }
        }
        presenter = PropertyPresenter.new(api_name: 'x', fragment:, template_index: { 'Article' => 'Article' })

        assert_equal ['Article'], presenter.target_templates
      end

      test 'classification_tree is nil without a tree_label' do
        assert_nil PropertyPresenter.new(api_name: 'x', fragment: {}, definition: {}).classification_tree
      end

      test 'classification_tree returns the label with a nil ctl_id when the tree is unknown' do
        presenter = PropertyPresenter.new(api_name: 'x', fragment: {}, definition: { 'tree_label' => 'this-tree-does-not-exist' })

        assert_equal 'this-tree-does-not-exist', presenter.classification_tree[:label]
        assert_nil presenter.classification_tree[:ctl_id]
      end

      test 'classification_tree resolves ctl_id from an injected batch map without a per-property DB query' do
        presenter = PropertyPresenter.new(
          api_name: 'x', fragment: {}, definition: { 'tree_label' => 'Tags' }, tree_label_ids: { 'Tags' => 42 }
        )

        # If the presenter fell through to the DB despite the batch map, this stub blows up.
        result = DataCycleCore::ConceptScheme.stub(:find_by, ->(*, **) { raise 'must not hit the DB when a batch map is present' }) do
          presenter.classification_tree
        end

        assert_equal({ label: 'Tags', ctl_id: 42 }, result)
      end

      test 'classification_tree with a batch map yields a nil ctl_id for a label missing from it' do
        presenter = PropertyPresenter.new(
          api_name: 'x', fragment: {}, definition: { 'tree_label' => 'Unlisted' }, tree_label_ids: { 'Tags' => 42 }
        )

        assert_equal({ label: 'Unlisted', ctl_id: nil }, presenter.classification_tree)
      end

      # ---------------- PropertyPresenter categories (filter facets, derived from data) ----------------

      test 'linked and embedded properties both fall under the :linked facet' do
        assert_includes PropertyPresenter.new(api_name: 'x', fragment: {}, definition: { 'type' => 'linked' }).categories, :linked
        assert_includes PropertyPresenter.new(api_name: 'x', fragment: {}, definition: { 'type' => 'embedded' }).categories, :linked
      end

      test 'an embedded property also gets its own :embedded facet, a plain linked one does not' do
        assert_includes PropertyPresenter.new(api_name: 'x', fragment: {}, definition: { 'type' => 'embedded' }).categories, :embedded
        assert_not_includes PropertyPresenter.new(api_name: 'x', fragment: {}, definition: { 'type' => 'linked' }).categories, :embedded
      end

      test 'a classification is a :classification facet, and so is a concept-typed ref without the flag' do
        assert_includes PropertyPresenter.new(api_name: 'x', fragment: {}, definition: { 'type' => 'classification' }).categories, :classification
        assert_includes PropertyPresenter.new(api_name: 'x', fragment: { '$ref' => '#/components/schemas/Concept' }).categories, :classification
      end

      test 'a geographic flag and a geo-typed ref both yield the :geo facet' do
        assert_includes PropertyPresenter.new(api_name: 'x', fragment: {}, definition: { 'type' => 'geographic' }).categories, :geo
        assert_includes PropertyPresenter.new(api_name: 'x', fragment: { '$ref' => '#/components/schemas/GeoCoordinates' }).categories, :geo
      end

      test 'a translated scalar is a :translated facet only (scalar is not a filter facet)' do
        categories = PropertyPresenter.new(
          api_name: 'x', fragment: { 'type' => 'string' }, definition: { 'storage_location' => 'translated_value' }
        ).categories

        assert_equal [:translated], categories
      end

      test 'a fulltext flag surfaces its own facet' do
        categories = PropertyPresenter.new(
          api_name: 'x', fragment: { 'type' => 'string' }, definition: { 'search' => true }
        ).categories

        assert_includes categories, :fulltext
      end

      test 'a plain scalar property has no filter facets' do
        assert_equal [], PropertyPresenter.new(api_name: 'x', fragment: { 'type' => 'integer' }, definition: {}).categories
      end

      test 'an envelope key with no delivered type has no facets' do
        assert_equal [], PropertyPresenter.new(api_name: '@type', fragment: { 'type' => 'array' }).categories
      end

      # ---------------- Document / TemplatePresenter (congruent with OpenAPI) ----------------

      test 'unknown :id resolves to nil so the controller can raise 404' do
        assert_nil Document.new.template('this-template-does-not-exist')
      end

      test 'a route :id resolves by template_name first' do
        template = DataCycleCore::ThingTemplate.first
        presenter = Document.new(locale: :en).template(template.template_name)

        assert_equal template.template_name, presenter.template_name
      end

      # find_template's second branch: an :id that is not a template_name but a
      # schema.org type (api_schema_types) still resolves — the route accepts both,
      # mirroring the previous controller. Exercises the ARRAY-overlap fallback.
      test 'a route :id resolves by schema.org type when no template_name matches' do
        document = Document.new(locale: :en)
        named = DataCycleCore::ThingTemplate.pluck(:template_name).to_set
        # a schema.org type that is NOT itself a template name (so the first branch misses).
        # Several templates may share the type, so we only assert the resolved one carries it.
        type = DataCycleCore::ThingTemplate.all.filter_map { |template|
          Array.wrap(template.api_schema_types).find { |t| named.exclude?(t) }
        }.first
        skip 'no template resolvable purely by its schema.org type in this instance' if type.nil?

        presenter = document.template(type)

        assert_not_nil presenter, "expected a presenter resolving '#{type}' via schema.org type"
        assert_includes Array.wrap(presenter.api_schema_types), type,
                        "resolved template must actually carry the schema.org type '#{type}'"
      end

      test 'the presented property keys are exactly the OpenAPI component keys (= api_name)' do
        template = DataCycleCore::ThingTemplate.first
        document = Document.new(locale: :en)
        component = document.schemas[DataCycleCore::OpenApi::EntityBuilder.component_name(template.template_name)]

        presented = document.template(template.template_name).properties.map(&:api_name)

        assert_equal component['properties'].keys, presented,
                     'UI keys must be 1:1 the components/schemas keys (no divergent key logic)'
      end

      test 'every ThingTemplate produces a presentable detail page' do
        document = Document.new(locale: :en)

        DataCycleCore::ThingTemplate.find_each do |template|
          presenter = document.template(template.template_name)

          assert_not_nil presenter, "expected a presenter for #{template.template_name}"
          assert_nothing_raised { presenter.properties.each(&:to_h) }
        end
      end

      # Regression guard for the raw_definitions join: if the join key (api_name_for)
      # ever diverges from the OpenAPI component key, every flag silently turns false.
      # We do not depend on a single property existing — only that SOME flag is derived
      # somewhere, which is impossible unless the definition join actually connects.
      test 'the raw definition join populates dc flags for at least some property' do
        document = Document.new(locale: :en)

        any_flag_set = DataCycleCore::ThingTemplate.all.any? do |template|
          document.template(template.template_name).properties.any? { |property| property.flags.value?(true) }
        end

        assert any_flag_set, 'expected the api_name join to surface at least one dc flag across all templates'
      end

      test 'filter_categories is a deduped subset of the canonical facet order' do
        document = Document.new(locale: :en)
        facets = document.template(DataCycleCore::ThingTemplate.first.template_name).filter_categories

        assert_equal facets.uniq, facets, 'no duplicate facets'
        assert(facets.all? { |category| PropertyPresenter::CATEGORY_ORDER.include?(category) })
        assert_equal PropertyPresenter::CATEGORY_ORDER.select { |category| facets.include?(category) }, facets,
                     'facets must follow the canonical order'
      end

      # schema_type_paths groups the schema.org hierarchy per PATH (Thing > Place >
      # Accommodation), not per segment — so the detail page renders one line per path,
      # like schema.org, instead of one line per word (#50201).
      FakeTemplate = Struct.new(:schema, :schema_ancestors)

      test 'schema_type_paths groups api.type into a single hierarchy path (not split per segment)' do
        template = FakeTemplate.new({ 'api' => { 'type' => ['Thing', 'Place', 'Accommodation'] } }, [])
        presenter = TemplatePresenter.new(template:, component: {})

        assert_equal [['Thing', 'Place', 'Accommodation']], presenter.schema_type_paths
      end

      test 'schema_type_paths strips dc:/dcls: internals from the api.type path' do
        template = FakeTemplate.new({ 'api' => { 'type' => ['Thing', 'dc:Foo', 'dcls:Bar', 'Place'] } }, [])
        presenter = TemplatePresenter.new(template:, component: {})

        assert_equal [['Thing', 'Place']], presenter.schema_type_paths
      end

      test 'schema_type_paths keeps each schema_ancestors path separate when api.type is absent' do
        template = FakeTemplate.new({}, [['Thing', 'Place', 'Accommodation'], ['Thing', 'Intangible', 'dcls:Foo']])
        presenter = TemplatePresenter.new(template:, component: {})

        assert_equal [['Thing', 'Place', 'Accommodation'], ['Thing', 'Intangible']], presenter.schema_type_paths
      end

      test 'schema_type_paths is empty when neither api.type nor schema_ancestors are present' do
        presenter = TemplatePresenter.new(template: FakeTemplate.new({}, []), component: {})

        assert_equal [], presenter.schema_type_paths
      end

      test 'schema_name is the flattened, dc:/dcls:-stripped type path (index subtitle contract)' do
        with_api = TemplatePresenter.new(template: FakeTemplate.new({ 'api' => { 'type' => ['Thing', 'dcls:X', 'Place'] } }, []), component: {})

        assert_equal ['Thing', 'Place'], with_api.schema_name

        # falls back to the (flattened) schema_ancestors when api.type is absent
        from_ancestors = TemplatePresenter.new(template: FakeTemplate.new({}, [['Thing', 'Place'], ['Thing', 'Intangible']]), component: {})

        assert_equal ['Thing', 'Place', 'Thing', 'Intangible'], from_ancestors.schema_name
      end

      # ---------------- TemplatePresenter#raw_definitions (overlay join + batched tree labels) ----------------

      # raw_definitions / tree_label_ids only touch the template thing, so a tiny
      # stand-in keeps the join logic deterministic and DB-free.
      OverlayFakeThing = Struct.new(:property_names, :api_names, :definitions) do
        def api_name_for(name)
          api_names[name]
        end

        def properties_for(name)
          definitions[name]
        end
      end
      OverlayFakeTemplate = Struct.new(:template_thing)

      def template_presenter_for(thing)
        TemplatePresenter.new(template: OverlayFakeTemplate.new(thing), component: {})
      end

      # An overlay *variant* and its base property both resolve to the same api_name
      # (Feature::Content::Overlay#api_name_for). The base owns the dc flags, so it
      # must win the join — a naive `||=` would keep whichever came first instead.
      test 'raw_definitions lets the base property own a shared api_name (base declared first)' do
        base = { 'type' => 'string', 'search' => true }
        overlay = { 'type' => 'string', 'features' => { 'overlay' => { 'overlay_for' => 'name' } } }
        thing = OverlayFakeThing.new(
          ['name', 'name_overlay'],
          { 'name' => 'name', 'name_overlay' => 'name' },
          { 'name' => base, 'name_overlay' => overlay }
        )

        assert_equal base, template_presenter_for(thing).send(:raw_definitions)['name']
      end

      test 'raw_definitions lets the base win even when the overlay variant is iterated first' do
        base = { 'type' => 'string', 'search' => true }
        overlay = { 'type' => 'string', 'features' => { 'overlay' => { 'overlay_for' => 'name' } } }
        # overlay variant FIRST in property order — a naive ||= would keep it and lose the base flags
        thing = OverlayFakeThing.new(
          ['name_overlay', 'name'],
          { 'name_overlay' => 'name', 'name' => 'name' },
          { 'name_overlay' => overlay, 'name' => base }
        )

        assert_equal base, template_presenter_for(thing).send(:raw_definitions)['name'],
                     'a non-overlay definition must win regardless of iteration order'
      end

      test 'tree_label_ids resolves every classification tree label in a single query (no N+1)' do
        thing = OverlayFakeThing.new(
          ['a', 'b', 'c'],
          { 'a' => 'a', 'b' => 'b', 'c' => 'c' },
          { 'a' => { 'tree_label' => 'Trees' }, 'b' => { 'tree_label' => 'Colors' }, 'c' => { 'type' => 'string' } }
        )
        presenter = template_presenter_for(thing)

        call_count = 0
        seen = nil
        relation = Object.new
        relation.define_singleton_method(:pluck) { |*| [] }
        DataCycleCore::ConceptScheme.stub(:where, lambda { |*args, **kwargs|
          call_count += 1
          seen = kwargs[:name] || args.first&.dig(:name)
          relation
        }) do
          presenter.send(:tree_label_ids)
        end

        assert_equal 1, call_count, 'exactly one batched query for all tree labels'
        assert_equal ['Trees', 'Colors'], seen, 'only the present, distinct tree labels are queried'
      end
    end
  end
end
