# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DeleteContentsUpdateAttributesTest < DataCycleCore::TestCases::ActiveSupportTestCase
    DummyUtilityObject = Struct.new(:external_source, :options, :steps_successful, :concept_map, :last_successful_try) do
      def source_steps_successful?
        steps_successful
      end

      def concept_by_path(path)
        concept_map&.dig(path)
      end
    end

    before(:all) do
      @subject = DataCycleCore::Generic::Common::DeleteContentsUpdateAttributes
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @utility_object = DummyUtilityObject.new(@local_system, {}, true, nil)

      DataCycleCore::Generic::Common::ImportFunctions.import_classification(
        utility_object: @utility_object,
        classification_data: { name: 'DCUA Tag', external_key: 'dcua-tag', tree_name: 'DCUA Tree' }
      )
      @tag_concepts = DataCycleCore::Concept.for_tree('DCUA Tree').with_internal_name('DCUA Tag')
      @utility_object.concept_map = { 'DCUA Tree > DCUA Tag' => @tag_concepts }
    end

    test 'process_content raises when source steps were not successful' do
      utility_object = DummyUtilityObject.new(@local_system, {}, false, nil)

      error = assert_raises(RuntimeError) do
        @subject.process_content(utility_object:, raw_data: {}, locale: :de, options: {})
      end
      assert_match('Update Attributes canceled', error.message)
    end

    test 'process_content raises when no external id is found in raw data' do
      options = { import: { external_key_path: 'id', attributes: [] } }

      error = assert_raises(RuntimeError) do
        @subject.process_content(utility_object: @utility_object, raw_data: {}, locale: :de, options:)
      end
      assert_match('No external id found!', error.message)
    end

    test 'process_content returns nil when no matching content exists' do
      options = { import: { external_key_path: 'id', attributes: [] } }

      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data: { 'id' => 'dcua-unknown' }, locale: :de, options:))
    end

    test 'process_content updates string attributes' do
      content = create_content('POI', { name: 'DCUA POI One', external_key: 'dcua-1', external_source_id: @local_system.id })
      options = { import: { external_key_path: 'id', attributes: [{ key: 'name', value: 'DCUA POI One Updated' }] } }

      @subject.process_content(utility_object: @utility_object, raw_data: { 'id' => 'dcua-1' }, locale: :de, options:)

      assert_equal('DCUA POI One Updated', content.reload.name)
    end

    test 'process_content applies external_key_prefix to find contents' do
      content = create_content('POI', { name: 'DCUA POI Two', external_key: 'PRE-dcua-2', external_source_id: @local_system.id })
      options = { import: { external_key_path: 'id', external_key_prefix: 'PRE-', attributes: [{ key: 'name', value: 'DCUA POI Two Updated' }] } }

      @subject.process_content(utility_object: @utility_object, raw_data: { 'id' => 'dcua-2' }, locale: :de, options:)

      assert_equal('DCUA POI Two Updated', content.reload.name)
    end

    test 'process_content deletes attributes with nil values' do
      content = create_content('POI', { name: 'DCUA POI Three', external_key: 'dcua-3', external_source_id: @local_system.id, date_created: '2024-01-15T10:00:00+01:00' })

      assert_not_nil(content.date_created)

      options = { import: { external_key_path: 'id', attributes: [{ key: 'date_created', value: nil }] } }

      @subject.process_content(utility_object: @utility_object, raw_data: { 'id' => 'dcua-3' }, locale: :de, options:)

      assert_nil(content.reload.date_created)
    end

    test 'process_content adds and removes classifications' do
      content = create_content('POI', { name: 'DCUA POI Four', external_key: 'dcua-4', external_source_id: @local_system.id })
      classification_id = @tag_concepts.pick(:classification_id)
      raw_data = { 'id' => 'dcua-4' }
      add_options = { import: { external_key_path: 'id', attributes: [{ key: 'universal_classifications', value: 'DCUA Tree > DCUA Tag' }] } }

      @subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options: add_options)

      assert_includes(content.reload.universal_classifications.pluck(:id), classification_id)

      delete_options = { import: { external_key_path: 'id', attributes: [{ key: 'universal_classifications', value: 'DCUA Tree > DCUA Tag', delete: true }] } }

      @subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options: delete_options)

      assert_not_includes(content.reload.universal_classifications.pluck(:id), classification_id)
    end

    test 'load_value_for_attribute casts values by attribute type' do
      assert_in_delta(3.14, @subject.load_value_for_attribute({ type: 'float', value: '3.14' }, @utility_object))
      assert_equal(42, @subject.load_value_for_attribute({ type: 'integer', value: '42' }, @utility_object))
      assert_equal('5', @subject.load_value_for_attribute({ type: 'string', value: 5 }, @utility_object))
      assert_nil(@subject.load_value_for_attribute({ type: 'datetime', value: 'x' }, @utility_object))
    end

    test 'load_value_for_attribute resolves classification ids by concept path' do
      value = @subject.load_value_for_attribute({ type: 'classification', value: 'DCUA Tree > DCUA Tag' }, @utility_object)

      assert_equal(@tag_concepts.pluck(:classification_id), value)
    end

    test 'validate_attributes assigns types and filters unknown attributes' do
      thing = create_content('POI', { name: 'DCUA POI Five' })
      attributes = @subject.validate_attributes(thing, [{ key: 'name', value: 'x' }, { key: 'not_a_real_attribute', value: 'y' }])

      assert_equal([{ key: 'name', value: 'x', type: 'string' }], attributes)
    end

    test 'validate_attributes raises for missing value keys' do
      thing = create_content('POI', { name: 'DCUA POI Six' })

      error = assert_raises(RuntimeError) do
        @subject.validate_attributes(thing, [{ key: 'name' }])
      end
      assert_match('value key must be defined', error.message)
    end

    test 'validate_attributes raises for duplicate key and value combinations' do
      thing = create_content('POI', { name: 'DCUA POI Seven' })

      error = assert_raises(RuntimeError) do
        @subject.validate_attributes(thing, [{ key: 'name', value: 'x' }, { key: 'name', value: 'x' }])
      end
      assert_match('must be unique', error.message)
    end
  end
end
