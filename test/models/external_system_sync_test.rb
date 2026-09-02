# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ExternalSystemSyncTest < ActiveSupport::TestCase
    def setup
      @content_count = DataCycleCore::Thing.count
      @external_system_count = DataCycleCore::ExternalSystem.count

      data = {
        'name' => 'My_test'
      }

      @data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: data)

      external_thing_data = {
        'key_1' => 'value_1'
      }
      @external_system = DataCycleCore::ExternalSystem.find_by(name: 'Local-System')
      @data_set.add_external_system_data(@external_system, external_thing_data)
    end

    test 'add and update data for external system' do
      assert_equal({ 'key_1' => 'value_1' }, @data_set.external_system_data(@external_system))

      assert_equal(DataCycleCore::Thing.count, @content_count + 1)
      assert_equal(DataCycleCore::ExternalSystem.count, @external_system_count)
      assert_equal(1, @data_set.external_system_syncs.count)

      update_data = { 'new_key_1' => 'new_value_1' }
      @data_set.add_external_system_data(@external_system, update_data)

      assert_equal(update_data, @data_set.external_system_data(@external_system))
    end

    test 'remove data for external system' do
      @data_set.remove_external_system_data(@external_system)

      assert_nil(@data_set.external_system_data(@external_system))

      assert_equal(DataCycleCore::Thing.count, @content_count + 1)
      assert_equal(DataCycleCore::ExternalSystem.count, @external_system_count)
      assert_equal(1, @data_set.external_system_syncs.count)
    end

    test 'delete thing' do
      @data_set.destroy_content

      assert_equal(DataCycleCore::Thing.count, @content_count)
      assert_equal(DataCycleCore::ExternalSystem.count, @external_system_count)
      assert_equal(0, @data_set.external_system_syncs.count)
    end

    test 'delete external system' do
      @external_system.destroy

      assert_equal(DataCycleCore::Thing.count, @content_count + 1)
      assert_equal(DataCycleCore::ExternalSystem.count, @external_system_count - 1)
      assert_equal(0, @data_set.external_system_syncs.count)
    end

    test 'exception_data_from extracts a readable message from the first present known key' do
      assert_equal 'boom', DataCycleCore::ExternalSystemSync.exception_data_from({ 'errors' => 'boom' })['text']
      assert_equal 'boom', DataCycleCore::ExternalSystemSync.exception_data_from({ 'job_message' => 'boom' })['text']
      # symbol-keyed payloads work too
      assert_equal 'boom', DataCycleCore::ExternalSystemSync.exception_data_from({ error: 'boom' })['text']
      # 'errors' takes precedence over 'message'
      assert_equal 'first', DataCycleCore::ExternalSystemSync.exception_data_from({ 'errors' => 'first', 'message' => 'second' })['text']
    end

    test 'exception_data_from handles blanks and strings, and ignores hashes without a known error key' do
      assert_nil DataCycleCore::ExternalSystemSync.exception_data_from(nil)
      assert_nil DataCycleCore::ExternalSystemSync.exception_data_from({})
      assert_equal 'plain error', DataCycleCore::ExternalSystemSync.exception_data_from('plain error')['text']
      # a hash carrying only unrelated keys must not be dumped as an error message
      assert_nil DataCycleCore::ExternalSystemSync.exception_data_from({ 'external_key' => 'x' })
    end

    test 'add_external_system_data records exception_data on failure and clears it on success' do
      @data_set.add_external_system_data(@external_system, { 'errors' => 'geometry invalid' }, 'failure')
      sync = @data_set.external_system_syncs.export.find_by(external_system_id: @external_system.id)

      assert_equal 'failure', sync.status
      assert_equal 'geometry invalid', sync.exception_data['text']

      @data_set.add_external_system_data(@external_system, nil, 'success')

      assert_nil sync.reload.exception_data
    end

    test 'display_exception_data falls back to raw sync data for failures recorded before exception_data existed' do
      sync = @data_set.external_system_syncs.export.find_by(external_system_id: @external_system.id)

      # simulate a pre-existing failure: error status, message only in the raw data, no exception key
      sync.update!(status: 'error', data: { 'errors' => 'legacy geometry error' })

      assert_nil sync.exception_data
      assert_equal 'legacy geometry error', sync.display_exception_data['text']
    end

    test 'display_exception_data returns nil for failures without error text and for non-failures' do
      sync = @data_set.external_system_syncs.export.find_by(external_system_id: @external_system.id)

      sync.update!(status: 'error', data: { 'external_key' => 'x' })

      assert_nil sync.display_exception_data

      sync.update!(status: 'success', data: { 'errors' => 'stale error' })

      assert_nil sync.display_exception_data
    end

    test 'external source to external systems sync' do
      external_source_id = DataCycleCore::ExternalSystem.first.id
      external_key = '1234'

      data_set2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })
      data_set2.external_key = external_key
      data_set2.external_source_id = external_source_id
      data_set2.save

      data_set2.external_source_to_external_system_syncs

      assert_equal(DataCycleCore::ExternalSystem.count, @external_system_count)
      assert_equal(1, data_set2.external_system_syncs.count)
      assert_nil(data_set2.external_key)
      assert_nil(data_set2.external_source_id)
      assert_equal(data_set2.external_system_syncs.first.external_system_id, external_source_id)
      assert_equal(data_set2.external_system_syncs.first.external_key, external_key)
    end
  end
end
