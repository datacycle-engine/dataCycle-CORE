# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # DC-01: /remote_render formerly rendered ANY in-tree partial (and invoked ANY helper via `try`)
  # with objects resolved from attacker-supplied {class,id} params (ParamsResolver) and no
  # per-partial authorization — letting a low-privileged user dump arbitrary ActiveRecord rows
  # (e.g. another user's API access_token) through the admin_panel partials, a one-request takeover.
  #
  # The endpoint now rejects anything outside an allowlist (DataCycleCore::RemoteRenderGuard). The
  # admin_panel partials are no longer reachable here at all — they are served only through the
  # authorized ContentsController#admin_panel action (see AdminPanelTest).
  class RemoteRenderTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    VICTIM_TOKEN = 'dc01-secret-access-token-value'

    setup do
      @routes = Engine.routes
      standard_role = DataCycleCore::Role.find_by(name: 'standard')

      @standard_user = DataCycleCore::User.where(email: 'dc01_standard@datacycle.at').first_or_create!(
        given_name: 'DC01', family_name: 'Standard',
        password: 'vdr5pmx@juv9BMJ6ujt', role_id: standard_role&.id, confirmed_at: 1.day.ago
      )
      @victim = DataCycleCore::User.where(email: 'dc01_victim@datacycle.at').first_or_create!(
        given_name: 'DC01', family_name: 'Victim',
        password: 'vdr5pmx@juv9BMJ6ujt', role_id: standard_role&.id, confirmed_at: 1.day.ago,
        access_token: VICTIM_TOKEN
      )

      sign_in(@standard_user)
    end

    test 'rejects admin_panel partials (the record-dump vector) with 403 and leaks nothing' do
      ['schema', 'template_path', 'datahash', 'thing_history_links', 'json_api', 'meta_data', 'data_export', 'data_send'].each do |panel|
        get remote_render_path, params: {
          partial: "data_cycle_core/application/admin_panel/#{panel}",
          options: { content: { class: 'DataCycleCore::User', id: @victim.id } }
        }

        assert_response :forbidden, "admin_panel/#{panel} must not be reachable via remote_render"
        assert_not_includes response.body, VICTIM_TOKEN
        assert_not_includes response.body, 'access_token'
      end
    end

    test 'rejects an arbitrary in-tree partial with 403' do
      get remote_render_path, params: { partial: 'data_cycle_core/contents/show' }

      assert_response :forbidden
    end

    test 'rejects path traversal with 403' do
      get remote_render_path, params: { partial: '../../../../etc/passwd' }

      assert_response :forbidden
    end

    test 'rejects an arbitrary render_function (try-invoked helper) with 403' do
      get remote_render_path, params: { render_function: 'destroy' }

      assert_response :forbidden
    end

    test 'still serves an allowlisted partial (no regression)' do
      get remote_render_path, params: { partial: 'data_cycle_core/stored_filters/search_history_short' }

      assert_response :success
      assert_not_equal 403, response.status
    end
  end
end
