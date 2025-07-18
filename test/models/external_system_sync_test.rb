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

    test 'add and update data for external system' do # rubocop:disable Minitest/MultipleAssertions
      assert_equal({ 'key_1' => 'value_1' }, @data_set.external_system_data(@external_system))

      assert_equal(DataCycleCore::Thing.count, @content_count + 1)
      assert_equal(DataCycleCore::ExternalSystem.count, @external_system_count)
      assert_equal(1, @data_set.external_system_syncs.count)

      update_data = { 'new_key_1' => 'new_value_1' }
      @data_set.add_external_system_data(@external_system, update_data)

      assert_equal(update_data, @data_set.external_system_data(@external_system))
    end

    test 'remove data for external system' do # rubocop:disable Minitest/MultipleAssertions
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

    test 'external source to external systems sync' do # rubocop:disable Minitest/MultipleAssertions
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
