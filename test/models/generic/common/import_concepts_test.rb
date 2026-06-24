# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ImportConceptsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    DummyExternalSource = Struct.new(:id, :default_options)
    DummyUtilityObject = Struct.new(:external_source, :options)

    before(:all) do
      @subject = DataCycleCore::Generic::Common::ImportConcepts
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @remote_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      @utility_object = DummyUtilityObject.new(DummyExternalSource.new('53a82828-d3aa-4765-99ca-7aef176de1c2', {}), {})
      @db_utility_object = DummyUtilityObject.new(@local_system, {})

      @scheme_by_key = DataCycleCore::ClassificationTreeLabel.create!(name: 'ICT Scheme Key', external_source_id: @local_system.id, external_key: 'ict-scheme-key')
      @scheme_by_name = DataCycleCore::ClassificationTreeLabel.create!(name: 'ICT Scheme Name', external_source_id: @local_system.id)

      import_functions = DataCycleCore::Generic::Common::ImportFunctions
      @parent_alias = import_functions.import_classification(utility_object: @db_utility_object, classification_data: { name: 'ICT Parent', external_key: 'ict-parent', tree_name: 'ICT Mapping Tree' })
      @child_alias = import_functions.import_classification(utility_object: @db_utility_object, classification_data: { name: 'ICT Child', external_key: 'ict-child', tree_name: 'ICT Mapping Tree' })
    end

    test 'process_content transforms raw data into concept hash' do
      options = {
        import: {
          locales: ['de'],
          external_id_prefix: 'PRE-',
          concept_scheme_external_id_prefix: 'CS-',
          concept_uri_prefix: 'https://uri.test/',
          concept_scheme: 'Fallback Scheme'
        }
      }
      raw_data = {
        'id' => '1', 'name' => 'Concept One', 'parent_id' => '0', 'description' => 'Desc',
        'uri' => 'path/1', 'order_a' => 5, 'concept_scheme_external_key' => 'sk',
        'mapped_concepts' => [{ 'id' => 'm1' }], 'geom' => 'POINT (1 2)'
      }
      result = @subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options:)
      expected = {
        external_key: 'PRE-1',
        external_source_id: @utility_object.external_source.id,
        name: 'Concept One',
        parent_external_key: 'PRE-0',
        description: 'Desc',
        uri: 'https://uri.test/path/1',
        order_a: 5,
        concept_scheme_external_key: 'CS-sk',
        concept_scheme_name: 'Fallback Scheme',
        mapped_concepts: [{ 'id' => 'm1' }],
        geom: 'POINT (1 2)'
      }

      assert_equal(expected, result)
    end

    test 'process_content returns nil for blank raw_data or missing import options' do
      raw_data = { 'id' => '1', 'name' => 'Concept' }

      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data: {}, locale: :de, options: { import: { locales: ['de'] } }))
      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options: {}))
      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options: { import: {} }))
    end

    test 'process_content only processes allowed locales' do
      raw_data = { 'id' => '1', 'name' => 'Concept' }
      options = { import: { locales: ['en'] } }

      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options:))

      utility_object = DummyUtilityObject.new(DummyExternalSource.new('uo-1', { locales: ['en'] }), {})
      options = { import: { import_mappings: true } }

      assert_nil(@subject.process_content(utility_object:, raw_data:, locale: :de, options:))
      assert_equal('1', @subject.process_content(utility_object:, raw_data:, locale: :en, options:)&.dig(:external_key))
    end

    test 'process_content returns nil when id or name is missing' do
      options = { import: { locales: ['de'] } }

      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data: { 'name' => 'No Id' }, locale: :de, options:))
      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data: { 'id' => '1' }, locale: :de, options:))
    end

    test 'process_content skips concepts from the current instance' do
      raw_data = { 'id' => '1', 'name' => 'Concept', 'external_system_identifier' => 'self-system' }
      options = { import: { locales: ['de'] }, current_instance_identifiers: ['self-system'] }

      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options:))
    end

    test 'process_content ignores parent id equal to own id and import_mappings false' do
      raw_data = { 'id' => '1', 'name' => 'Concept', 'parent_id' => '1', 'mapped_concepts' => [{ 'id' => 'm1' }] }
      options = { import: { locales: ['de'], import_mappings: false } }
      result = @subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options:)

      assert_not(result.key?(:parent_external_key))
      assert_empty(result[:mapped_concepts])
    end

    test 'extract_property digs path from options or falls back to identifier' do
      options = { import: { concept_name_path: 'nested.label' } }

      assert_equal('Deep Name', @subject.extract_property({ 'nested' => { 'label' => 'Deep Name' } }, options, 'name'))
      assert_equal('Plain Name', @subject.extract_property({ 'name' => 'Plain Name' }, {}, 'name'))
    end

    test 'transform_concept_scheme_identifiers groups concepts by scheme external key' do
      data_array = [{ external_key: 'c1', external_source_id: @local_system.id, name: 'C One', concept_scheme_external_key: 'ict-scheme-key', unknown_key: 'dropped' }]
      result = @subject.transform_concept_scheme_identifiers(data_array:, options: { import: {} })

      assert_equal(1, result.size)
      assert_equal(@scheme_by_key.id, result.keys.first.id)
      assert_equal([{ external_key: 'c1', external_source_id: @local_system.id, name: 'C One' }], result.values.first)
    end

    test 'transform_concept_scheme_identifiers resolves schemes by mapped name' do
      data_array = [{ external_key: 'c2', external_source_id: @local_system.id, name: 'C Two', concept_scheme_name: 'Raw Name' }]
      options = { import: { concept_scheme_name_mapping: { 'Raw Name' => 'ICT Scheme Name' } } }
      result = @subject.transform_concept_scheme_identifiers(data_array:, options:)

      assert_equal(1, result.size)
      assert_equal(@scheme_by_name.id, result.keys.first.id)
      assert_equal([{ external_key: 'c2', external_source_id: @local_system.id, name: 'C Two' }], result.values.first)
    end

    test 'transform_concept_scheme_identifiers rejects missing schemes and foreign external systems' do
      data_array = [
        { external_key: 'c3', external_source_id: @local_system.id, name: 'C Three', concept_scheme_name: 'ICT Missing Scheme' },
        { external_key: 'c4', external_source_id: @remote_system.id, name: 'C Four', concept_scheme_name: 'ICT Scheme Name' }
      ]
      result = @subject.transform_concept_scheme_identifiers(data_array:, options: { import: {} })

      assert_empty(result)
    end

    test 'external_system_identifiers_to_ids! resolves identifiers and names to ids' do
      data_array = [
        { name: 'A', external_system_identifier: 'local-system' },
        { name: 'B', external_system_identifier: 'Remote-System' }
      ]
      result = @subject.external_system_identifiers_to_ids!(data_array:)

      assert_equal(@local_system.id, result.first[:external_source_id])
      assert_equal(@remote_system.id, result.second[:external_source_id])
      assert(result.none? { |da| da.key?(:external_system_identifier) })
    end

    test 'external_system_identifiers_to_ids! applies external_systems_mapping' do
      data_array = [{ name: 'A', external_system_identifier: 'legacy-system' }]
      result = @subject.external_system_identifiers_to_ids!(data_array:, external_systems_mapping: { 'legacy-system' => 'local-system' })

      assert_equal(@local_system.id, result.first[:external_source_id])
    end

    test 'external_system_identifiers_to_ids! leaves unknown identifiers without id' do
      data_array = [{ name: 'A', external_source_id: 'original-id', external_system_identifier: 'ict-unknown-system' }]
      result = @subject.external_system_identifiers_to_ids!(data_array:)

      assert_equal('original-id', result.first[:external_source_id])
      assert_not(result.first.key?(:external_system_identifier))
    end

    test 'external_system_identifiers_to_ids! creates missing external systems on demand' do
      data_array = [{ name: 'A', external_system_identifier: 'ict-brand-new-system' }]
      result = @subject.external_system_identifiers_to_ids!(data_array:, import_external_systems: true)
      new_system = DataCycleCore::ExternalSystem.find_by(identifier: 'ict-brand-new-system')

      assert_not_nil(new_system)
      assert_equal(new_system.id, result.first[:external_source_id])
    end

    test 'transform_data_array resolves external systems and groups by scheme' do
      data_array = [{ external_key: 'c5', name: 'C Five', external_system_identifier: 'local-system', concept_scheme_external_key: 'ict-scheme-key' }]
      result = @subject.transform_data_array(data_array:, options: { import: {} })

      assert_equal(@scheme_by_key.id, result.keys.first.id)
      assert_equal([{ external_key: 'c5', external_source_id: @local_system.id, name: 'C Five' }], result.values.first)
    end

    test 'map_concept_mappings builds parent/child pairs from mapped_concepts' do
      data_array = [
        { external_key: 'p1', external_source_id: 'es-1', mapped_concepts: [{ id: 'cid-1', external_key: 'cek-1', external_system_identifier: 'esi-1', full_path: 'A > B' }] },
        { external_key: 'p2', external_source_id: 'es-1' }
      ]
      result = @subject.map_concept_mappings(data_array:, utility_object: @utility_object)
      parent = { external_key: 'p1', external_source_id: 'es-1' }

      assert_equal(2, result.size)
      assert_equal({ parent:, child: { external_key: 'cek-1', external_source_id: @utility_object.external_source.id, external_system_identifier: 'esi-1', full_path: 'A > B' } }, result.first)
      assert_equal({ parent:, child: { external_key: 'cid-1', external_source_id: @utility_object.external_source.id, full_path: 'A > B' } }, result.second)
    end

    test 'mappings_for_existing_concepts resolves concepts by external key and by full path' do
      concept_mappings = [
        { parent: { external_key: 'ict-parent', external_source_id: @local_system.id }, child: { external_key: 'ict-child', external_source_id: @local_system.id, full_path: 'Unknown > Path' } },
        { parent: { external_key: 'ict-parent', external_source_id: @local_system.id }, child: { external_key: 'ict-missing', external_source_id: @local_system.id, full_path: 'ICT Mapping Tree > ICT Child' } }
      ]
      result = @subject.mappings_for_existing_concepts(concept_mappings:)
      expected = { parent_id: @parent_alias.id, child_id: @child_alias.id, link_type: 'related' }

      assert_equal([expected, expected], result)
    end

    test 'mappings_for_existing_concepts drops unresolvable mappings' do
      concept_mappings = [
        { parent: { external_key: 'ict-unknown-parent', external_source_id: @local_system.id }, child: { external_key: 'ict-child', external_source_id: @local_system.id, full_path: 'Unknown > Path' } }
      ]

      assert_empty(@subject.mappings_for_existing_concepts(concept_mappings:))
    end

    test 'transform_concept_mappings resolves mapped concepts to concept links' do
      data_array = [{ external_key: 'ict-parent', external_source_id: @local_system.id, mapped_concepts: [{ id: 'ict-child', full_path: 'Unknown > Path' }] }]
      result = @subject.transform_concept_mappings(data_array:, utility_object: @db_utility_object, options: { import: {} })

      assert_equal([{ parent_id: @parent_alias.id, child_id: @child_alias.id, link_type: 'related' }], result)
    end

    test 'transform_geometries maps geometries to classification alias ids' do
      data_array = [
        { external_source_id: @local_system.id, external_key: 'ict-child', geom: 'MULTIPOLYGON (((1 1, 2 2, 3 3, 1 1)))' },
        { external_source_id: @local_system.id, external_key: 'ict-parent', geom: BSON::Binary.new('wkb-bytes') },
        { external_source_id: @local_system.id, external_key: 'ict-unknown', geom: 'POINT (1 2)' },
        { external_source_id: @local_system.id, external_key: 'ict-no-geom' }
      ]
      result = @subject.transform_geometries(data_array:)

      assert_equal(2, result.size)
      assert_includes(result, { classification_alias_id: @child_alias.id, geom: 'MULTIPOLYGON (((1 1, 2 2, 3 3, 1 1)))' })
      assert_includes(result, { classification_alias_id: @parent_alias.id, geom: 'wkb-bytes' })
    end

    test 'transform_geometries returns empty array without geometries' do
      assert_empty(@subject.transform_geometries(data_array: [{ external_key: 'ict-child' }]))
      assert_empty(@subject.transform_geometries(data_array: []))
    end
  end
end
