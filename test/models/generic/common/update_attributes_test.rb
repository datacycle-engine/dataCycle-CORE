# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class GenericCommonUpdateAttributesTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Generic::Common::UpdateAttributes

    UaDummyUtilityObject = Struct.new(:external_source, :steps_successful, :last_successful_try, :mode) do
      def source_steps_successful?
        steps_successful
      end
    end

    class UaFilterObject
      attr_reader :excepted

      def except(*args)
        @excepted = args
        self
      end

      def with_locale
        self
      end

      def query
        [:item]
      end
    end

    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @classification_id = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 3').pick(:classification_id)
    end

    def utility_object(steps_successful: true, last_successful_try: nil)
      UaDummyUtilityObject.new(@external_source, steps_successful, last_successful_try, nil)
    end

    # ---- dispatch / iterator ----

    test 'import_data forces full mode and dispatches to import_contents' do
      object = utility_object
      captured = nil

      DataCycleCore::Generic::Common::ImportFunctions.stub(:import_contents, ->(**kwargs) { captured = kwargs }) do
        SUBJECT.import_data(utility_object: object, options: { import: {} })
      end

      assert_equal :full, object.mode
      assert_equal object, captured[:utility_object]
      assert_predicate captured[:iterator], :present?
      assert_predicate captured[:data_processor], :present?
    end

    test 'load_contents strips deletion scopes and runs the localized query' do
      filter_object = UaFilterObject.new

      result = SUBJECT.load_contents(filter_object:)

      assert_equal [:item], result
      assert_equal [:without_deleted, :without_archived, :with_deleted], filter_object.excepted
    end

    # ---- load_value_for_attribute ----

    test 'load_value_for_attribute casts values by attribute type' do
      assert_in_delta 3.14, SUBJECT.load_value_for_attribute({ type: 'float', value: '3.14' })
      assert_equal 42, SUBJECT.load_value_for_attribute({ type: 'integer', value: '42' })
      assert_equal '5', SUBJECT.load_value_for_attribute({ type: 'string', value: 5 })
      assert_nil SUBJECT.load_value_for_attribute({ type: 'datetime', value: 'x' })
    end

    test 'load_value_for_attribute resolves classification ids by internal name and tree label' do
      value = SUBJECT.load_value_for_attribute({ type: 'classification', value: 'Tag 3', tree_label: 'Tags' })

      assert_includes value, @classification_id
    end

    # ---- process_content ----

    test 'process_content raises when the source steps were not successful' do
      error = assert_raises(RuntimeError) do
        SUBJECT.process_content(utility_object: utility_object(steps_successful: false), raw_data: {}, locale: :de, options: {})
      end

      assert_match 'Update Attributes canceled', error.message
    end

    test 'process_content raises when no recent successful download exists before the delete deadline' do
      options = { import: { last_successful_try: 'Time.zone.local(2026, 1, 1)', external_key_path: 'id', attributes: [] } }
      object = utility_object(last_successful_try: Time.zone.local(2020, 1, 1))

      error = assert_raises(RuntimeError) do
        SUBJECT.process_content(utility_object: object, raw_data: { 'id' => 'x' }, locale: :de, options:)
      end

      assert_match 'No recent successful download detected', error.message
    end

    test 'process_content raises when no external id is found in the raw data' do
      options = { import: { external_key_path: 'id', attributes: [] } }

      error = assert_raises(RuntimeError) do
        SUBJECT.process_content(utility_object: utility_object, raw_data: {}, locale: :de, options:)
      end

      assert_match 'No external id found!', error.message
    end

    test 'process_content returns nil when no matching content exists' do
      options = { import: { external_key_path: 'id', attributes: [] } }

      assert_nil SUBJECT.process_content(utility_object: utility_object, raw_data: { 'id' => 'ua-unknown' }, locale: :de, options:)
    end

    test 'process_content updates string attributes and applies the external key prefix' do
      content = create_content('POI', { name: 'UA POI One', external_key: 'PRE-ua-1', external_source_id: @external_source.id })
      options = { import: { external_key_path: 'id', external_key_prefix: 'PRE-', attributes: [{ key: 'name', type: 'string', value: 'UA POI One Updated' }] } }

      SUBJECT.process_content(utility_object: utility_object, raw_data: { 'id' => 'ua-1' }, locale: :de, options:)

      assert_equal 'UA POI One Updated', content.reload.name
    end

    test 'process_content adds and removes universal classifications' do
      content = create_content('POI', { name: 'UA POI Two', external_key: 'ua-2', external_source_id: @external_source.id })
      raw_data = { 'id' => 'ua-2' }
      add_options = { import: { external_key_path: 'id', attributes: [{ key: 'universal_classifications', type: 'classification', value: 'Tag 3', tree_label: 'Tags' }] } }

      SUBJECT.process_content(utility_object: utility_object, raw_data:, locale: :de, options: add_options)

      assert_includes content.reload.universal_classifications.pluck(:id), @classification_id

      delete_options = { import: { external_key_path: 'id', attributes: [{ key: 'universal_classifications', type: 'classification', value: 'Tag 3', tree_label: 'Tags', delete: true }] } }

      SUBJECT.process_content(utility_object: utility_object, raw_data:, locale: :de, options: delete_options)

      assert_not_includes content.reload.universal_classifications.pluck(:id), @classification_id
    end
  end
end
