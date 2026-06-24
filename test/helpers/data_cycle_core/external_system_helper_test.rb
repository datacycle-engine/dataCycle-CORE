# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ExternalSystemHelperTest < ActionView::TestCase
    include DataCycleCore::ExternalSystemHelper
    include DataCycleCore::AdministrationHelper
    include DataCycleCore::UiLocaleHelper

    test 'external_systems_tooltip is empty without a source or syncs' do
      assert_equal '', external_systems_tooltip(nil, nil)
    end

    test 'external_systems_tooltip marks the primary source and counts duplicates' do
      source = struct_double(name: 'Feratel')
      syncs = [
        struct_double(external_system: struct_double(name: 'Feratel')),
        struct_double(external_system: struct_double(name: 'Outdooractive'))
      ]

      assert_equal 'Feratel * (2)<br>Outdooractive', external_systems_tooltip(source, syncs)
    end

    test 'external_sync_status_icon picks an icon per sync type' do
      assert_includes external_sync_status_icon('success', 'import'), 'fa-stack'
      assert_includes external_sync_status_icon('success', 'duplicate'), 'fa-clone'
      assert_includes external_sync_status_icon('success', 'something'), 'fa-link'
    end

    test 'external_sync_status_icon overrides the icon for pending and failed states' do
      assert_includes external_sync_status_icon('pending', 'import'), 'fa-refresh'
      assert_includes external_sync_status_icon('failure', 'export'), 'fa-times'
      assert_includes external_sync_status_icon('error', 'import'), 'fa-times'
    end

    test 'external_sync_status_icon adds a tooltip when a status message is requested' do
      assert_includes external_sync_status_icon('success', 'import', true), 'data-dc-tooltip'
    end

    test 'last_step_status derives a status from the try timestamps' do
      assert_equal 'unkown', last_step_status({})
      assert_equal 'done', last_step_status({ 'last_try' => 'x', 'status' => 'done' })
      assert_equal 'finished', last_step_status({ 'last_try' => '2024-01-01', 'last_successful_try' => '2024-01-01' })
      assert_equal 'running', last_step_status({ 'last_try' => '2024-01-02', 'last_successful_try' => '2024-01-01' })
      assert_equal 'error', last_step_status({ 'last_try' => '2024-01-01', 'last_successful_try' => '2024-01-02' })
    end

    test 'last_step_icon picks a direction icon from the key prefix' do
      assert_includes last_step_icon('d_pull'), 'fa-long-arrow-down'
      assert_includes last_step_icon('i_push'), 'fa-long-arrow-right'
      assert_includes last_step_icon('other'), 'fa-circle'
      assert_includes last_step_icon(nil), 'fa-circle'
    end

    test 'last_step_duration renders a status icon when not finished' do
      assert_includes last_step_duration(nil, 'running'), 'fa-spinner'
      assert_includes last_step_duration('x', 'error'), 'fa-times'
      assert_includes last_step_duration(nil, 'other'), 'fa-circle'
    end

    test 'last_step_duration formats the duration with a scaled unit' do
      assert_includes last_step_duration(30, 'finished'), '30s'
      assert_includes last_step_duration(120, 'finished'), '2m'
      assert_includes last_step_duration(7200, 'finished'), '2h'
    end

    test 'last_step_tooltip is nil without a last try' do
      assert_nil last_step_tooltip({})
    end

    test 'last_step_tooltip renders the last try timestamp' do
      assert_includes last_step_tooltip({ 'last_try' => '2024-01-15T09:30:00' }), '15.01.2024 09:30'
    end

    test 'external_system_template_paths is indexed by file basename' do
      assert_kind_of Hash, external_system_template_paths
    end
  end
end
