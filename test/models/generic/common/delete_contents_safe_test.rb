# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DeleteContentsSafeTest < DataCycleCore::TestCases::ActiveSupportTestCase
    DummyUtilityObject = Struct.new(:external_source)
    RawItem = Struct.new(:dumped) do
      def dump
        dumped
      end
    end

    before(:all) do
      @subject = DataCycleCore::Generic::Common::DeleteContentsSafe
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @utility_object = DummyUtilityObject.new(@local_system)
    end

    # raw_data items respond to #dump → { locale => { path => external_key } }
    def raw_for(*keys)
      keys.map { |key| RawItem.new({ de: { 'id' => key } }) }
    end

    test 'import_data delegates to ImportFunctions.delete_data' do
      received = {}
      DataCycleCore::Generic::Common::ImportFunctions.stub(:delete_data, ->(**kwargs) { received = kwargs }) do
        @subject.import_data(utility_object: @utility_object, options: { a: 1 })
      end

      assert_equal({ a: 1 }, received[:options])
    end

    test 'load_contents queries including deleted contents' do
      filter = Object.new
      filter.define_singleton_method(:with_deleted) { filter }
      filter.define_singleton_method(:query) { [:result] }

      assert_equal([:result], @subject.load_contents(filter_object: filter))
    end

    test 'process_content cleans up orphaned duplicate syncs and returns zero when nothing matches' do
      DataCycleCore::ExternalSystemSync.create!(external_system_id: @local_system.id, sync_type: 'duplicate', external_key: 'dcs-orphan', syncable_type: 'DataCycleCore::Thing', syncable_id: SecureRandom.uuid)
      options = { import: { external_key_path: 'id' } }

      result = nil
      assert_difference('DataCycleCore::ExternalSystemSync.count', -1) do
        result = @subject.process_content(utility_object: @utility_object, raw_data: raw_for('dcs-orphan'), locale: :de, options:)
      end

      assert_equal(0, result)
    end

    test 'process_content applies the external_key_prefix when matching' do
      options = { import: { external_key_path: 'id', external_key_prefix: 'PRE-' } }

      assert_equal(0, @subject.process_content(utility_object: @utility_object, raw_data: raw_for('dcs-none'), locale: :de, options:))
    end

    test 'process_content deletes a matching single-locale content' do
      create_content('POI', { name: 'DCS One', external_key: 'dcs-1', external_source_id: @local_system.id })
      options = { import: { external_key_path: 'id', template_name: 'POI' } }

      assert_equal(1, @subject.process_content(utility_object: @utility_object, raw_data: raw_for('dcs-1'), locale: :de, options:))
    end

    test 'process_content deletes all duplicates when delete_all_duplicates is set' do
      create_content('POI', { name: 'DCS Two', external_key: 'dcs-2', external_source_id: @local_system.id })
      options = { import: { external_key_path: 'id', delete_all_duplicates: true } }

      assert_equal(1, @subject.process_content(utility_object: @utility_object, raw_data: raw_for('dcs-2'), locale: :de, options:))
    end
  end
end
