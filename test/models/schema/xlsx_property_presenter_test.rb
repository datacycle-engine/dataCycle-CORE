# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class Schema
    # Unit tests for the property-level view-model contract that the /schema XLSX
    # export (and, in future, the /schema/:id detail view) consume — the single
    # source that removes duplicated schema traversal / api_name logic.
    #
    # Everything is derived at runtime from the live templates: the tests assert
    # the presenter agrees with the schema definitions and with the single-source
    # Content#api_name_for, never against hard-coded names or types.
    class XlsxPropertyPresenterTest < DataCycleCore::TestCases::ActiveSupportTestCase
      COLLECTION_TYPES = ['embedded', 'linked'].freeze
      CONTRACT_FIELDS = [:api_name, :label, :expected_type, :cardinality, :flags, :target_template, :nested].freeze

      before(:all) do
        @templates_by_name = DataCycleCore::ThingTemplate.all.index_by(&:template_name)
        @template_things = @templates_by_name.values.map(&:template_thing)
      end

      def presenter_for(content)
        DataCycleCore::Schema::XlsxPropertyPresenter.new(content, templates_by_name: @templates_by_name)
      end

      test 'nodes expose the contract for every documented property, from the single-source api_name' do
        content = @template_things.find { |t| t.schema['content_type'] == 'entity' } || @template_things.first

        assert content, 'no template to present'

        # every attribute the API documents — same single source the export uses
        properties = documented_properties_of(content)
        nodes = presenter_for(content).nodes

        assert_equal properties.size, nodes.size, 'one node per API property'

        properties.each_with_index do |(key, definition), index|
          node = nodes[index]

          # api_name comes from THE single source, not a re-implementation
          assert_equal content.api_name_for(key, definition), node[:api_name], "api_name for #{key}"
          assert_equal_or_nil definition['label'], node[:label], "label for #{key}"
          assert_equal_or_nil definition['type'], node[:expected_type], "expected_type for #{key}"

          expected_cardinality = COLLECTION_TYPES.include?(definition['type']) ? 'many' : 'one'

          assert_equal expected_cardinality, node[:cardinality], "cardinality for #{key}"

          assert_equal_or_nil Array.wrap(definition['template_name']).presence, node[:target_template], "target_template for #{key}"

          expected_tree_label = definition['type'] == 'classification' ? definition['tree_label'] : nil

          assert_equal_or_nil expected_tree_label, node[:tree_label], "tree_label for #{key}"

          # full contract shape present
          CONTRACT_FIELDS.each do |field|
            assert node.key?(field), "node for #{key} is missing #{field}"
          end
          assert_equal definition['type'] == 'classification', node[:flags][:classification], "classification flag for #{key}"
          assert_equal definition['type'] == 'embedded', node[:flags][:embedded], "embedded flag for #{key}"
        end
      end

      test 'embedded properties nest exactly the target template API properties (no duplicated traversal)' do
        found = nil
        @template_things.each do |content|
          properties = content.schema['properties']
          properties.each do |key, definition|
            next unless definition['type'] == 'embedded'
            next unless DataCycleCore::OpenApi::PropertyFilter.documented?(key, definition, properties)

            name = Array.wrap(definition['template_name']).first
            embedded = @templates_by_name[name]
            next if embedded.nil? || name == content.template_name

            found = [content, name, embedded.template_thing]
            break
          end
          break if found
        end

        skip 'no resolvable non-recursive embedded property in the schema' if found.nil?

        content, target_name, embedded = found
        # locate the embedded node by its target template (node order is filtered, not raw)
        node = presenter_for(content).nodes.find { |n| n[:expected_type] == 'embedded' && Array.wrap(n[:target_template]).include?(target_name) }

        assert node, 'embedded node must be present'
        assert node[:nested], 'embedded property must nest its target template'
        embedded_properties = documented_properties_of(embedded)

        assert_equal embedded_properties.size, node[:nested].size, 'one nested node per documented embedded property'

        embedded_properties.each_with_index do |(embedded_key, embedded_definition), embedded_index|
          nested_node = node[:nested][embedded_index]

          assert_equal embedded.api_name_for(embedded_key, embedded_definition), nested_node[:api_name], "nested api_name for #{embedded_key}"
        end
      end

      # The export hides only what the API hides outright: the internal key type,
      # api-disabled and overlay variants (PropertyFilter.documented?). A plain
      # property and a classification (delivered aggregated as dc:classification)
      # are BOTH kept — classifications must stay in the documentation export.
      test 'hidden properties are dropped but classifications are kept' do
        content = StubContent.new('X', {
          'properties' => {
            'id' => { 'type' => 'key' },
            'hidden' => { 'type' => 'string', 'api' => { 'disabled' => true } },
            'title_overlay' => { 'type' => 'string', 'features' => { 'overlay' => { 'overlay_for' => 'name' } } },
            'tags' => { 'type' => 'classification', 'tree_label' => 'Tags' },
            'name' => { 'type' => 'string' }
          }
        })
        presenter = DataCycleCore::Schema::XlsxPropertyPresenter.new(content, templates_by_name: { 'X' => content })

        nodes = presenter.nodes

        assert_equal ['tags', 'name'], nodes.pluck(:api_name), 'key/disabled/overlay dropped; classification + plain kept'

        tags = nodes.find { |n| n[:api_name] == 'tags' }

        assert tags[:flags][:classification], 'the classification flag drives the tree hint in the export'
        assert_equal 'Tags', tags[:tree_label]
      end

      # Deterministic (no DB dependency): A embeds B embeds A — the hop back into
      # the ancestor A must be cut off, not expanded forever.
      test 'recursion is cut off for a self-referential embedded chain' do
        a = StubContent.new('A', { 'properties' => { 'to_b' => embedded_definition('B') } })
        b = StubContent.new('B', { 'properties' => { 'to_a' => embedded_definition('A') } })
        presenter = DataCycleCore::Schema::XlsxPropertyPresenter.new(a, templates_by_name: { 'A' => a, 'B' => b })

        to_b = presenter.nodes.first

        assert_not to_b[:flags][:recursive], 'the first hop A→B is not recursive'
        assert to_b[:nested], 'B is expanded'

        to_a = to_b[:nested].first

        assert to_a[:flags][:recursive], 'the hop B→A back into an ancestor is cut off'
        assert_nil to_a[:nested], 'the recursive node is not expanded'
        assert_equal ['A'], to_a[:target_template]
      end

      # type_label is a pure display helper for a leaf's scalar type; container and
      # linked rows carry no scalar type of their own and must return nil.
      test 'type_label maps known scalar schema types to their display label' do
        assert_equal 'Text', DataCycleCore::Schema::XlsxPropertyPresenter.type_label('string')
        assert_equal 'Text', DataCycleCore::Schema::XlsxPropertyPresenter.type_label('key')
        assert_equal 'DateTime', DataCycleCore::Schema::XlsxPropertyPresenter.type_label('datetime')
        assert_equal 'Classification', DataCycleCore::Schema::XlsxPropertyPresenter.type_label('classification')
      end

      test 'type_label capitalizes an unmapped scalar type as a fallback' do
        assert_equal 'Number', DataCycleCore::Schema::XlsxPropertyPresenter.type_label('number')
        assert_equal 'Boolean', DataCycleCore::Schema::XlsxPropertyPresenter.type_label('boolean')
      end

      test 'type_label is nil for container and linked types (they carry no scalar type)' do
        assert_nil DataCycleCore::Schema::XlsxPropertyPresenter.type_label('embedded')
        assert_nil DataCycleCore::Schema::XlsxPropertyPresenter.type_label('object')
        assert_nil DataCycleCore::Schema::XlsxPropertyPresenter.type_label('linked')
      end

      # The 'object' branch of nested_for expands inline sub-fields against the SAME
      # template thing (not a separate template), still applying the documented? filter.
      test 'an object property expands its inline sub-fields against the same template' do
        content = StubContent.new('X', {
          'properties' => {
            'address' => { 'type' => 'object', 'label' => 'Address', 'properties' => {
              'street' => { 'type' => 'string', 'label' => 'Street' },
              'secret' => { 'type' => 'string', 'api' => { 'disabled' => true } }
            } }
          }
        })
        presenter = DataCycleCore::Schema::XlsxPropertyPresenter.new(content, templates_by_name: { 'X' => content })

        node = presenter.nodes.first

        assert_equal 'object', node[:expected_type]
        assert_equal 'one', node[:cardinality], 'an object is a single nested value, not a collection'
        assert node[:nested], 'an object expands its inline sub-fields'
        assert_equal ['street'], node[:nested].pluck(:api_name), 'only documented sub-fields (api-disabled dropped)'
      end

      # An embedded property whose target template is absent from the lookup must
      # degrade gracefully (no nested rows) and is NOT flagged as a recursion cut-off.
      test 'an embedded property with an unknown target template yields no nested rows' do
        content = StubContent.new('X', { 'properties' => { 'to_missing' => embedded_definition('DoesNotExist') } })
        presenter = DataCycleCore::Schema::XlsxPropertyPresenter.new(content, templates_by_name: { 'X' => content })

        node = presenter.nodes.first

        assert_equal 'embedded', node[:expected_type]
        assert_not node[:flags][:recursive], 'an unresolvable target is not a recursion cut-off'
        assert_nil node[:nested], 'an unresolvable embedded target simply has no nested rows'
      end

      private

      # The documented properties of a content, in schema order — the single
      # source the presenter itself uses, so the test tracks the skip rules.
      def documented_properties_of(content)
        properties = content.schema['properties']
        properties.select do |key, definition|
          DataCycleCore::OpenApi::PropertyFilter.documented?(key, definition, properties)
        end
      end

      def assert_equal_or_nil(expected, actual, message = nil)
        expected.nil? ? assert_nil(actual, message) : assert_equal(expected, actual, message)
      end

      def embedded_definition(template_name)
        { 'type' => 'embedded', 'template_name' => template_name, 'label' => "to #{template_name}" }
      end

      # Minimal stand-in for a template-thing / template: the presenter only calls
      # #schema, #template_name and #api_name_for (pure over the passed definition).
      class StubContent
        attr_reader :template_name, :schema

        def initialize(template_name, schema)
          @template_name = template_name
          @schema = schema
        end

        def api_name_for(key, _definition)
          key.to_s.camelize(:lower)
        end

        # the stub is its own template thing (mirrors ThingTemplate#template_thing)
        def template_thing
          self
        end
      end
    end
  end
end
