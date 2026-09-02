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
      assert_includes external_sync_status_icon('success', 'import', include_status_message: true), 'data-dc-tooltip'
    end

    test 'external_sync_status_icon only includes the webhook error when explicitly shown' do
      exception_data = { 'status' => 500, 'message' => 'boom' }

      hidden = external_sync_status_icon('failure', 'export', exception_data:, include_status_message: true)
      shown = external_sync_status_icon('failure', 'export', exception_data:, include_status_message: true, show_webhook_error: true)

      assert_not_includes hidden, 'boom'
      assert_includes shown, 'boom'
    end

    test 'external_sync_status_icon ignores a non-hash exception_data' do
      result = external_sync_status_icon('failure', 'export', exception_data: 'a plain string', include_status_message: true, show_webhook_error: true)

      assert_not_includes result, 'plain string'
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

    test 'external_systems_with_details includes the primary external source' do
      es = struct_double(name: 'Feratel', last_successful_import: Time.zone.now, id: 'es-1')
      es.define_singleton_method(:external_detail_url) { |_c| 'http://example.com/detail' }
      es.define_singleton_method(:external_url) { |_c| 'http://example.com/edit' }

      syncs_relation = Object.new
      def syncs_relation.includes(*_args) = self

      def syncs_relation.find_each
      end

      content = struct_double(
        external_source: es,
        external_system_syncs: syncs_relation,
        updated_at: Time.zone.now,
        external_key: 'key-1',
        id: 'c-1'
      )

      result = external_systems_with_details(content)

      assert result.key?(es)
      assert_equal ['success'], result[es]['meta']['status']
      assert_equal 'key-1', result[es]['import'].first[:external_key]
    end

    test 'external_system_template_options lists templates not yet configured' do
      dir = Dir.mktmpdir
      path = File.join(dir, 'my_new_system.yml.erb')
      File.write(path, "name: my_new_system\nidentifier: my_new_system\n")

      DataCycleCore.stub(:external_system_template_paths, [path]) do
        assert_includes external_system_template_options, 'my_new_system'
      end
    ensure
      FileUtils.remove_entry(dir) if dir
    end

    test 'last_step_tooltip renders the last successful try when it differs' do
      data = {
        'last_try' => '2024-01-15T09:30:00',
        'last_try_time' => 120,
        'last_successful_try' => '2024-01-14T09:30:00',
        'last_successful_try_time' => 60
      }

      html = last_step_tooltip(data, 'finished')

      assert_includes html, '14.01.2024'
    end
  end
end
