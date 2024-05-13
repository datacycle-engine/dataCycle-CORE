# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentExternalDataTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @primary_key = '4321'
      @primary_external_system = DataCycleCore::ExternalSystem.first

      @secondary_key = '1234'
      @secondary_system_id = ExternalSystem.last.id

      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })
      @content.update_columns(external_source_id: @primary_external_system.id, external_key: @primary_key)

      @secondary_system_sync = DataCycleCore::ExternalSystemSync.create(syncable: @content, external_system_id: @secondary_system_id, external_key: @secondary_key, status: 'success', sync_type: 'duplicate', data: { external_key: @secondary_key })
    end

    test 'switch_primary_external_system works' do
      @content.switch_primary_external_system(@secondary_system_sync)

      assert_equal(@secondary_system_id, @content.external_source_id)
      assert_equal(@secondary_key, @content.external_key)

      assert(@content.external_system_syncs.exists?(external_system_id: @primary_external_system.id, sync_type: 'duplicate', external_key: @primary_key))
    end

    test 'switch_primary_external_system ActiveRecord::RecordNotUnique' do
      content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 2' })
      content2.update_columns(external_source_id: @secondary_system_id, external_key: @secondary_key)

      assert_raises(ActiveRecord::RecordNotUnique) do
        @content.switch_primary_external_system(@secondary_system_sync)
      end

      @content.reload

      assert_equal(@primary_external_system.id, @content.external_source_id)
      assert_equal(@primary_key, @content.external_key)

      assert(@content.external_system_syncs.exists?(external_system_id: @secondary_system_id, sync_type: 'duplicate', external_key: @secondary_key))
    end
  end
end
