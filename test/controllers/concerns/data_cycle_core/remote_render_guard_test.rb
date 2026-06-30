# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # SECURITY (DC-01): the remote_render allowlist must permit the legitimate partials (incl. the
  # dynamic prefix families) and helper render_functions, while rejecting everything else:
  # admin-panel partials, arbitrary in-tree partials, path traversal and arbitrary method names.
  class RemoteRenderGuardTest < DataCycleCore::TestCases::ActiveSupportTestCase
    class FakeController < ActionController::API
      include DataCycleCore::RemoteRenderGuard
    end

    setup do
      @controller = FakeController.new
    end

    def allowed_partial?(partial)
      @controller.send(:remote_render_partial_allowed?, partial)
    end

    def allowed_function?(function)
      @controller.send(:remote_render_function_allowed?, function)
    end

    test 'allows exact allowlisted partials' do
      assert allowed_partial?('data_cycle_core/contents/related')
      assert allowed_partial?('data_cycle_core/object_browser/editor_overlay')
      assert allowed_partial?('data_cycle_core/stored_filters/search_history_short')
    end

    test 'allows the dynamic partial families by prefix' do
      assert allowed_partial?('data_cycle_core/contents/new/bild')
      assert allowed_partial?('data_cycle_core/contents/new/shared/new_form')
      assert allowed_partial?('data_cycle_core/contents/grid/compact/attributes/title')
    end

    test 'rejects admin_panel partials (served as authorized turbo frames instead)' do
      ['schema', 'template_path', 'datahash', 'thing_history_links', 'json_api', 'meta_data', 'data_export', 'data_send'].each do |panel|
        assert_not allowed_partial?("data_cycle_core/application/admin_panel/#{panel}"), "admin_panel/#{panel} must be rejected"
      end
    end

    test 'rejects path traversal, absolute paths and malformed names' do
      ['../../../etc/passwd', '/etc/passwd', 'data_cycle_core/../users/show',
       'data_cycle_core/contents/related.rb', 'Foo/Bar', 'data_cycle_core//related', '', nil].each do |partial|
        assert_not allowed_partial?(partial), "expected #{partial.inspect} to be rejected"
      end
    end

    test 'rejects in-tree partials that are not on the allowlist' do
      assert_not allowed_partial?('data_cycle_core/contents/show')
      assert_not allowed_partial?('devise/sessions/new')
      assert_not allowed_partial?('layouts/application')
    end

    test 'allows only the known render_functions' do
      ['advanced_graph_filter_advanced_type', 'render_content_tile_details', 'render_linked_partial', 'render_specific_translatable_attribute_editor', 'render_specific_translatable_attribute_viewer', 'render_specific_translatable_title_attribute_viewer'].each do |function|
        assert allowed_function?(function), "#{function} should be allowed"
      end
    end

    test 'rejects arbitrary method names as render_function' do
      ['destroy', 'delete', 'update_all', 'send', 'eval', 'system', 'to_json', 'current_user'].each do |function|
        assert_not allowed_function?(function), "#{function} must be rejected"
      end
      assert_not allowed_function?('')
      assert_not allowed_function?(nil)
    end

    test 'host apps can extend the allowlist via DataCycleCore config' do
      assert_not allowed_partial?('my_host_app/widgets/sidebar')
      assert_not allowed_partial?('my_host_app/dynamic/whatever')
      assert_not allowed_function?('host_custom_render')

      DataCycleCore.additional_remote_render_partials = ['my_host_app/widgets/sidebar']
      DataCycleCore.additional_remote_render_partial_prefixes = ['my_host_app/dynamic/']
      DataCycleCore.additional_remote_render_functions = ['host_custom_render']

      assert allowed_partial?('my_host_app/widgets/sidebar')
      assert allowed_partial?('my_host_app/dynamic/whatever')
      assert allowed_function?('host_custom_render')
    ensure
      DataCycleCore.additional_remote_render_partials = []
      DataCycleCore.additional_remote_render_partial_prefixes = []
      DataCycleCore.additional_remote_render_functions = []
    end
  end
end
