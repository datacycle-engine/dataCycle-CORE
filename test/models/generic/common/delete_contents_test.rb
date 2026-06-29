# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DeleteContentsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    DummyUtilityObject = Struct.new(:external_source, :last_successful_try, :steps_successful, :mode) do
      def source_steps_successful?
        steps_successful
      end
    end

    before(:all) do
      @subject = DataCycleCore::Generic::Common::DeleteContents
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @other_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      @utility_object = DummyUtilityObject.new(@local_system, Time.zone.now, true)
    end

    test 'import_data delegates to ImportFunctions with full mode' do
      utility_object = DummyUtilityObject.new(@local_system, nil, true)
      received = {}
      DataCycleCore::Generic::Common::ImportFunctions.stub(:import_contents, ->(**kwargs) { received = kwargs }) do
        @subject.import_data(utility_object:, options: { a: 1 })
      end

      assert_equal(:full, utility_object.mode)
      assert_equal({ a: 1 }, received[:options])
    end

    test 'load_contents drops the deleted/archived scopes and queries' do
      filter = Object.new
      filter.define_singleton_method(:except) { |*_a| filter }
      filter.define_singleton_method(:with_locale) { filter }
      filter.define_singleton_method(:query) { [:result] }

      assert_equal([:result], @subject.load_contents(filter_object: filter))
    end

    test 'process_content raises when source steps were not successful' do
      utility_object = DummyUtilityObject.new(@local_system, nil, false)

      error = assert_raises(RuntimeError) do
        @subject.process_content(utility_object:, raw_data: {}, locale: :de, options: {})
      end
      assert_match('Delete canceled', error.message)
    end

    test 'process_content raises when there is no recent successful download before the delete deadline' do
      utility_object = DummyUtilityObject.new(@local_system, nil, true)
      options = { import: { last_successful_try: 'Time.zone.now', external_key_path: 'id' } }

      error = assert_raises(RuntimeError) do
        @subject.process_content(utility_object:, raw_data: { 'id' => 'x' }, locale: :de, options:)
      end
      assert_match('No recent successful download', error.message)
    end

    test 'process_content raises when no external id is found in raw data' do
      options = { import: { external_key_path: 'id' } }

      error = assert_raises(RuntimeError) do
        @subject.process_content(utility_object: @utility_object, raw_data: {}, locale: :de, options:)
      end
      assert_match('No external id found', error.message)
    end

    test 'process_content destroys a duplicate external_system_sync when no content matches' do
      DataCycleCore::ExternalSystemSync.create!(external_system_id: @local_system.id, sync_type: 'duplicate', external_key: 'dc-del-orphan', syncable_type: 'DataCycleCore::Thing', syncable_id: SecureRandom.uuid)
      options = { import: { external_key_path: 'id' } }

      assert_difference('DataCycleCore::ExternalSystemSync.count', -1) do
        @subject.process_content(utility_object: @utility_object, raw_data: { 'id' => 'dc-del-orphan' }, locale: :de, options:)
      end
    end

    test 'process_content is a no-op when neither content nor sync exist' do
      options = { import: { external_key_path: 'id', external_key_prefix: 'PRE-' } }

      assert_nothing_raised do
        @subject.process_content(utility_object: @utility_object, raw_data: { 'id' => 'dc-del-nothing' }, locale: :de, options:)
      end
    end

    test 'process_content destroys matching content without a duplicate sync' do
      content = create_content('POI', { name: 'DC Del One', external_key: 'dc-del-1', external_source_id: @local_system.id })
      options = { import: { external_key_path: 'id' } }

      @subject.process_content(utility_object: @utility_object, raw_data: { 'id' => 'dc-del-1' }, locale: :de, options:)

      assert_nil(DataCycleCore::Thing.find_by(id: content.id))
    end

    test 'process_content reassigns matching content to its oldest duplicate sync' do
      content = create_content('POI', { name: 'DC Del Two', external_key: 'dc-del-2', external_source_id: @local_system.id })
      DataCycleCore::ExternalSystemSync.create!(external_system_id: @other_system.id, sync_type: 'duplicate', external_key: 'dc-del-2-dup', syncable: content)
      options = { import: { external_key_path: 'id' } }

      @subject.process_content(utility_object: @utility_object, raw_data: { 'id' => 'dc-del-2' }, locale: :de, options:)

      assert_equal(@other_system.id, content.reload.external_source_id)
    end
  end
end
