# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # DC-01: /remote_render renders in-tree partials with objects resolved from attacker-supplied
  # {class,id} params (ParamsResolver) and no per-partial authorization. The admin_panel partials
  # must not let a low-privileged user dump arbitrary ActiveRecord rows — e.g. another user's API
  # access_token — which previously allowed a one-request account takeover.
  class RemoteRenderTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    VICTIM_TOKEN = 'dc01-secret-access-token-value'

    UNGUARDED_ADMIN_PANEL_PARTIALS = [
      'data_cycle_core/application/admin_panel/data_send',
      'data_cycle_core/application/admin_panel/json_api',
      'data_cycle_core/application/admin_panel/meta_data',
      'data_cycle_core/application/admin_panel/data_export',
      'data_cycle_core/application/admin_panel/thing_history_links'
    ].freeze

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

    test 'remote_render admin_panel partials do not dump a user record (access_token) by class+id' do
      UNGUARDED_ADMIN_PANEL_PARTIALS.each do |partial|
        get remote_render_path, params: {
          partial:,
          options: { content: { class: 'DataCycleCore::User', id: @victim.id } }
        }

        assert_response :success
        assert_not_includes response.body, VICTIM_TOKEN, "#{partial} leaked the user's access_token"
        assert_not_includes response.body, 'access_token', "#{partial} leaked user record fields"
      end
    end

    test 'remote_render data_send still renders legitimate plain (non-record) data' do
      get remote_render_path, params: {
        partial: 'data_cycle_core/application/admin_panel/data_send',
        options: { content: { example_key: 'example_value' } }
      }

      assert_response :success
      assert_includes response.body, 'example_value'
    end
  end
end
