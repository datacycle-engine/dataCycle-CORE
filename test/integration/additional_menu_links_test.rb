# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AdditionalMenuLinksTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @routes = Engine.routes
    end

    setup do
      @links = DataCycleCore.features[:additional_menu_link][:links].deep_dup
      sign_in(DataCycleCore::User.find_by(email: 'tester@datacycle.at'))
    end

    def teardown
      configure(@links)
    end

    # DataCycleCore.features is frozen at the top level, so only nested keys can be written
    def configure(links)
      DataCycleCore.features[:additional_menu_link][:links] = links
      DataCycleCore::Feature::AdditionalMenuLink.reload
    end

    test 'an external link renders in its own sidebar section' do
      configure({ 'grist' => { 'url' => 'https://grist.example.com/', 'icon' => 'table' } })

      get root_path

      assert_response :success
      assert_select 'div.settings-row a.additional-menu-link.grist-link[href=?][target=?]', 'https://grist.example.com/', '_blank' do
        assert_select 'i.fa.fa-table'
      end
    end

    test 'a relative url is rendered below root_path' do
      configure({ 'grafana' => { 'url' => '/grafana', 'icon' => 'line-chart' } })

      get root_path

      assert_response :success
      assert_select 'a.additional-menu-link.grafana-link[href=?]', File.join(root_path, 'grafana')
    end

    test 'a link gated by a permission the user lacks is hidden' do
      configure({ 'locked' => { 'url' => 'https://locked.example.com/', 'permission' => 'not_a_granted_permission' } })

      get root_path

      assert_response :success
      assert_select 'a.locked-link', false
    end

    test 'no section is rendered without visible links' do
      configure({})

      get root_path

      assert_response :success
      assert_select 'a.additional-menu-link', false
    end
  end
end
