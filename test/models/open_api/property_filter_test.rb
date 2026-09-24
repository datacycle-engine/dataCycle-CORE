# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module OpenApi
    # Tests DataCycleCore::OpenApi::PropertyFilter — the single source of the v4
    # "is this a delivered API attribute?" skip rules, shared by EntityBuilder
    # (component schemas) and the /schema XLSX export. The rules are asserted
    # deterministically against a content double, and the module is proven to
    # agree with EntityBuilder over every real ThingTemplate so the two never
    # drift apart.
    class PropertyFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # Minimal content double: PropertyFilter calls #api_name_for and reads
      # #schema to resolve an overlay variant against its base. By default the
      # api_name is the camelCased key; an override lets a test force an envelope
      # collision, and +properties+ supplies the sibling map.
      class FakeContent
        def initialize(api_name: nil, properties: {})
          @api_name = api_name
          @properties = properties
        end

        def api_name_for(name, _definition = nil)
          @api_name || name.to_s.camelize(:lower)
        end

        def schema
          { 'properties' => @properties }
        end
      end

      def api_property?(name, definition, combined: [], content: FakeContent.new)
        PropertyFilter.api_property?(content, name, definition, combined:)
      end

      # The renderer's own property filter, included rather than reimplemented so
      # the parity guard below cannot drift from it. The two ivars are what
      # ThingRendererV4 assigns for v4 (api_context 'api', api_version 4); without
      # them ApiHelper#api_definition returns {} and nothing reads as disabled.
      class RendererRules
        include DataCycleCore::ApiHelper

        def initialize
          @api_version = 4
          @api_context = 'api'
        end
      end

      # --- api_definition (pure) -------------------------------------------

      test 'api_definition merges the v4 overrides over the base and drops other versions' do
        definition = { 'api' => { 'disabled' => false, 'name' => 'base', 'v4' => { 'name' => 'four' }, 'v3' => { 'name' => 'three' } } }
        api_def = PropertyFilter.api_definition(definition)

        assert_equal 'four', api_def['name'], 'v4 override wins over the base'
        assert_not api_def.key?('v3'), 'other version blocks are dropped'
        assert_not api_def.key?('v4'), 'the v4 block is merged in, not left nested'
      end

      test 'api_definition is empty for a definition without api config' do
        assert_empty PropertyFilter.api_definition({})
      end

      # --- skip rules ------------------------------------------------------

      test 'a plain property is delivered' do
        assert api_property?('name', { 'type' => 'string' })
      end

      test 'api-disabled properties are skipped (base and via v4 override)' do
        assert_not api_property?('x', { 'type' => 'string', 'api' => { 'disabled' => true } })
        assert_not api_property?('x', { 'type' => 'string', 'api' => { 'v4' => { 'disabled' => true } } })
      end

      test 'the internal key type is skipped (the identifier is exposed via @id)' do
        assert_not api_property?('id', { 'type' => 'key' })
      end

      test 'a classification without a custom partial is skipped, with a partial it is delivered' do
        assert_not api_property?('tags', { 'type' => 'classification' })
        assert api_property?('tags', { 'type' => 'classification', 'api' => { 'partial' => 'my_partial' } })
      end

      test 'overlay variants are skipped while their base carries the api name' do
        overlay = { 'type' => 'string', 'features' => { 'overlay' => { 'overlay_for' => 'name' } } }
        content = FakeContent.new(properties: { 'name' => { 'type' => 'string' }, 'name_overlay' => overlay })

        assert_not api_property?('name_overlay', overlay, content:)
        assert api_property?('name', { 'type' => 'string' }, content:), 'the base documents the api name'
      end

      # Aggregate templates disable the base attribute and leave `<name>_overlay`
      # the only enabled carrier of the api name. Skipping both dropped `name`,
      # `address` and `image` from every aggregate component while the API kept
      # delivering them (ordered_api_properties skips only the disabled base).
      test 'an overlay variant is documented when its base is api-disabled' do
        base = { 'type' => 'string', 'api' => { 'disabled' => true } }
        overlay = { 'type' => 'string', 'features' => { 'overlay' => { 'overlay_for' => 'name' } } }
        content = FakeContent.new(properties: { 'name' => base, 'name_overlay' => overlay })

        assert_not api_property?('name', base, content:), 'the disabled base stays hidden'
        assert api_property?('name_overlay', overlay, content:), 'the overlay is the only carrier left'
      end

      test 'documented? falls back to skipping an overlay variant without a sibling map' do
        overlay = { 'type' => 'string', 'features' => { 'overlay' => { 'overlay_for' => 'name' } } }

        assert_not PropertyFilter.documented?('name_overlay', overlay)
      end

      test 'combined/transformed properties are skipped (emitted once as additionalProperty)' do
        assert_not api_property?('street', { 'type' => 'string' }, combined: ['street'])
        assert api_property?('street', { 'type' => 'string' }, combined: ['other'])
      end

      test 'a property whose api_name collides with an envelope key is skipped (envelope wins)' do
        envelope_content = FakeContent.new(api_name: '@id')

        assert_not api_property?('whatever', { 'type' => 'string' }, content: envelope_content)
      end

      # --- documented? (broad: for the /schema XLSX export) ----------------

      test 'documented? hides api-disabled, the key type and redundant overlay variants' do
        siblings = { 'name' => { 'type' => 'string' } }

        assert_not PropertyFilter.documented?('x', { 'type' => 'string', 'api' => { 'disabled' => true } }, siblings)
        assert_not PropertyFilter.documented?('id', { 'type' => 'key' }, siblings)
        assert_not PropertyFilter.documented?('name_overlay', { 'type' => 'string', 'features' => { 'overlay' => { 'overlay_for' => 'name' } } }, siblings)
      end

      # The v4 renderer drops DataHashHelper::INTERNAL_PROPERTIES before it renders
      # anything, so a template property named after one is never delivered. Without
      # this rule the schema advertised dateCreated/dateModified/dateDeleted on
      # nearly every template, alongside the dct:created/dct:modified that ship.
      test 'documented? hides the internal data attributes the renderer never emits' do
        DataCycleCore::DataHashHelper::INTERNAL_PROPERTIES.each do |key|
          assert_not PropertyFilter.documented?(key, { 'type' => 'datetime' }, {}),
                     "#{key} is an internal attribute and is never delivered by v4"
        end
      end

      test 'documented? keeps classifications and combined-source properties (api_property? drops them)' do
        classification = { 'type' => 'classification', 'tree_label' => 'Tags' }
        combined_source = { 'type' => 'string' }

        # kept for the export (the API delivers them aggregated)
        assert PropertyFilter.documented?('tags', classification, {})
        assert PropertyFilter.documented?('street', combined_source, {})

        # but they are NOT named component properties
        assert_not api_property?('tags', classification)
        assert_not api_property?('street', combined_source, combined: ['street'])
      end

      # --- agreement with EntityBuilder over the real schema ----------------

      test 'accepted api_names all appear as component properties (no drift vs EntityBuilder)' do
        templates = DataCycleCore::ThingTemplate.first(30)

        assert_operator templates.size, :>, 0, 'expected the dummy instance to define ThingTemplates'

        accepted = 0

        templates.each do |template|
          thing = template.template_thing
          combined = thing.combined_property_names('v4')
          component_keys = EntityBuilder.new(template, locale: I18n.default_locale).call['properties'].keys.to_set

          template.schema_sorted['properties'].each do |name, definition|
            next unless PropertyFilter.api_property?(thing, name, definition, combined:)

            accepted += 1
            api_name = thing.api_name_for(name) || name

            assert_includes component_keys, api_name,
                            "#{template.template_name}: #{name} -> #{api_name} passes the filter but is missing from the component"
          end
        end

        # guard against a vacuous pass: if the filter regressed to reject everything
        # the loop above would never assert, yet still "pass" green.
        assert_operator accepted, :>, 0, 'the filter must accept real properties (over-exclusion guard)'
      end

      # The counter-direction, and the one that was missing: a key the renderer
      # delivers but the component never declares cannot be read by a client
      # generated from the document, and nothing here would say so. Two real cases
      # this catches: an overlay variant whose base is api-disabled (every
      # aggregate's name/address/image), and the internal date_created/date_modified/
      # date_deleted, which ordered_api_properties drops before rendering.
      test 'every api_name the v4 renderer emits is a component property' do
        templates = DataCycleCore::ThingTemplate.all
        rules = RendererRules.new

        assert_operator templates.size, :>, 0, 'expected the dummy instance to define ThingTemplates'

        undocumented = templates.flat_map do |template|
          thing = template.template_thing
          combined = thing.combined_property_names('v4')
          component_keys = EntityBuilder.new(template, locale: I18n.default_locale).call['properties'].keys.to_set

          rules.ordered_api_properties(validation: template.schema).filter_map do |key, definition|
            # the two skips _content_properties.jb applies on top of ordered_api_properties
            next if definition['type'] == 'classification' && PropertyFilter.api_definition(definition)['partial'].blank?
            next if combined.include?(key)

            api_name = thing.api_name_for(key, definition) || key
            next if component_keys.include?(api_name)

            "#{template.template_name}: #{key} -> #{api_name}"
          end
        end

        assert_empty undocumented,
                     "the v4 renderer emits api_names the component schema does not declare:\n#{undocumented.join("\n")}"
      end
    end
  end
end
