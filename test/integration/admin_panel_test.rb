# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # DC-01 (Layer 4): the admin-panel tabs are served by per-tab authorized Turbo-frame actions
  # (DataCycleCore::AdminPanelActions), not the generic remote_render endpoint. A shared
  # before_action loads the Thing and runs `authorize! :show_admin_panel` (super_admin only) before
  # any tab builds its payload — so the old "dump any row by class+id" primitive is gone: there is
  # no class/id input and a non-Thing id simply 404s.
  #
  # Seeded roles: admin@datacycle.at = super_admin (rank 99, has show_admin_panel),
  # guest@datacycle.at = guest (rank 0, no backend access).
  class AdminPanelTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    PANELS = DataCycleCore::AdminPanelActions::PANELS

    setup do
      @routes = Engine.routes
      @super_admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @guest = DataCycleCore::User.find_by(email: 'guest@datacycle.at')
      @article = DataCycleCore::Thing.where_translated_value(name: 'AdminPanelArticle').first ||
                 DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'AdminPanelArticle' })
    end

    test 'super_admin loads every admin_panel tab as its matching turbo frame' do
      sign_in(@super_admin)

      PANELS.each do |panel|
        get send("admin_panel_#{panel}_thing_path", @article)

        assert_response :success, "panel #{panel} should render"
        assert_includes response.body, "admin_panel_#{panel}_#{@article.id}", "panel #{panel} frame id missing"
      end
    end

    test 'the schema tab renders the controller-built JSON payload' do
      sign_in(@super_admin)
      get admin_panel_schema_thing_path(@article)

      assert_response :success
      assert_includes response.body, 'formatted-json'
    end

    test 'every admin_panel tab denies a user without show_admin_panel' do
      sign_in(@guest)

      PANELS.each do |panel|
        get send("admin_panel_#{panel}_thing_path", @article)

        assert_response :redirect, "panel #{panel} must deny guest (AccessDenied → redirect)"
        assert_not_includes response.body, 'formatted-json'
      end
    end

    test 'a non-Thing id (e.g. a User id) cannot be dumped — it 404s' do
      sign_in(@super_admin)
      get admin_panel_datahash_thing_path(id: @guest.id)

      assert_response :not_found
    end
  end
end
