# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ImportDataHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include Generic::Common::ImportFunctionsDataHelper

    before(:all) do
      @high_priority_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @medium_priority_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      @low_priority_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system-2')

      @content1 = create_content('POI', { name: 'High Priority System', external_key: 'high1', external_source_id: @high_priority_system.id})
      @content1.add_external_system_data(@medium_priority_system, { external_key: 'high-medium' }, 'success', 'duplicate', 'high-medium', false)
      @content1.add_external_system_data(@low_priority_system, { external_key: 'high-low' }, 'success', 'duplicate', 'high-low', false)

      @content2 = create_content('POI', { name: 'Medium Priority System', external_key: 'medium1', external_source_id: @medium_priority_system.id })
      @content2.add_external_system_data(@high_priority_system, { external_key: 'medium-high' }, 'success', 'duplicate', 'medium-high', false)
      @content2.add_external_system_data(@medium_priority_system, { external_key: 'medium-low' }, 'success', 'duplicate', 'medium-low', false)

      @content3 = create_content('POI', { name: 'Low Priority System', external_key: 'low1', external_source_id: @low_priority_system.id})
      @content3.add_external_system_data(@high_priority_system, { external_key: 'low-high' }, 'success', 'duplicate', 'low-high', false)
      @content3.add_external_system_data(@low_priority_system, { external_key: 'low-medium' }, 'success', 'duplicate', 'low-medium', false)

      @priority_list = [@high_priority_system.name, @medium_priority_system.name, @low_priority_system.name]

      @options = {
        primary_system_priority: @priority_list
      }
    end

    # Test-cases to determine, wheter to changing the primary system or not
    test 'system should become primary - returns true' do
      assert_equal(true, update_primary_system?(@content2, @high_priority_system, 'medium-high', @options))
    end

    test 'system should not become primary - returns false' do
      result = update_primary_system?(@content2, @low_priority_system, 'medium-low', @options)
      assert_equal(false, result)
    end

    test 'system already is primary - returns false' do
      assert_equal(false, update_primary_system?(@content2, @medium_priority_system, 'medium1', @options))
    end

    test 'system not in priority list - returns false' do
      unknown_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system-3')
      assert_equal(false, update_primary_system?(@content2, unknown_system, 'medium-unknown', @options))
    end

    test 'priority list does not exist - returns false' do
      priority_list = {
        something_else: {
        }
      }
      assert_equal(false, update_primary_system?(@content2, @high_priority_system, 'medium-high', priority_list))
    end

    # Test-cases to change the primary system
    test 'does not change anything if sync to delete is not found' do
      change_content = create_content('POI', { name: 'Change Content ', external_key: 'medium2', external_source_id: @medium_priority_system.id })
      change_content.add_external_system_data(@high_priority_system, { external_key: 'medium-high-2' }, 'success', 'duplicate', 'medium-high-2', false)
      data = { 'external_key' => 'medium-high-2' }

      delete_hash = change_primary_system(content: change_content, data:, new_external_source: @low_priority_system)

      assert_equal(true, change_content.changed?)
      assert_not_equal({}, delete_hash)
      assert_equal(@low_priority_system.id, change_content.external_source_id)
      assert_equal('medium-high-2', change_content.external_key)
      assert_equal(change_content.external_system_syncs.pluck(:external_system_id).sort, [@high_priority_system.id, @medium_priority_system.id].sort)
    end

    test 'marks the old sync for destruction and updates content source/key' do
      change_content = create_content('POI', { name: 'Change Content 2', external_key: 'medium3', external_source_id: @medium_priority_system.id })
      change_content.add_external_system_data(@high_priority_system, { external_key: 'medium-high-3' }, 'success', 'duplicate', 'medium-high-3', false)
      change_content.add_external_system_data(@low_priority_system, { external_key: 'medium-low-3' }, 'success', 'duplicate', 'medium-low-3', false)

      data = {
        'external_key' => 'medium-high-3'
      }

      delete_hash = change_primary_system(content: change_content, data:, new_external_source: @high_priority_system)

      assert_equal(['external_key', 'external_source_id'].sort, change_content.changed_attributes.keys.sort)

      change_content.save

      assert_equal(@high_priority_system.id, change_content.external_source_id)
      assert_equal('medium-high-3', change_content.external_key)

      secondary_ids = change_content.external_system_syncs.pluck(:external_system_id)
      assert_equal([@medium_priority_system.id, @low_priority_system.id].sort, secondary_ids.sort)
      assert_not_equal({}, delete_hash)
    end
  end
end
