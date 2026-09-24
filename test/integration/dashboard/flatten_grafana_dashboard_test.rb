# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Dashboard
    # The upload half of the procedure documented on DataCycleCore::GrafanaDashboardFlattener;
    # the transformation itself is covered by GrafanaDashboardFlattenerTest.
    class FlattenGrafanaDashboardTest < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers
      include Engine.routes.url_helpers

      setup do
        @routes = Engine.routes
        @system_admin = DataCycleCore::User.find_or_create_by!(email: 'system-admin@datacycle.at') do |user|
          user.given_name = 'System'
          user.password = 'Zx91KQp420aBvT7Lm'
          user.confirmed_at = 1.day.ago
          user.providers = { 'pixelpoint_aad_v2' => 'test-system-admin' } # system_admin role requires an OAuth provider
          user.role = DataCycleCore::Role.find_by(name: 'system_admin')
        end
        sign_in(@system_admin)
      end

      test 'the admin dashboard offers it in the maintenance section' do
        get admin_path

        assert_response :success
        assert_includes response.body, 'flatten-grafana-dashboard-button'
        assert_includes response.body, admin_flatten_grafana_dashboard_form_path
      end

      test 'the form is rendered into its turbo-frame' do
        get admin_flatten_grafana_dashboard_form_path

        assert_response :success
        assert_includes response.body, 'admin_dashboard_flatten_grafana_dashboard_form'
        assert_includes response.body, 'flatten-grafana-dashboard-form'
      end

      test 'an upload is rewritten and offered for download, the file riding along in the link' do
        post admin_flatten_grafana_dashboard_path, params: { dashboard: upload(dashboard_json) }

        assert_response :success
        assert_includes response.body, 'Analytics'
        assert_includes response.body, 'flatten-grafana-dashboard-download'
        assert_includes response.body, 'download="analytics-extern.json"'

        flattened = JSON.parse(downloaded_json_from(response.body))

        assert_equal "AND ctl.name = 'Administrative Einheiten'", flattened.dig('spec', 'elements', 'panel-1', 'spec', 'data', 'spec', 'queries', 0, 'spec', 'query', 'spec', 'rawSql')
        assert_empty flattened.dig('spec', 'variables')
      end

      # Rails.cache is the NullStore in development, so a download fetched in a second request would
      # report itself expired every time; the link carries the file instead of a key to one.
      test 'the download needs no second request and no server side state' do
        post admin_flatten_grafana_dashboard_path, params: { dashboard: upload(dashboard_json) }

        assert_response :success
        assert_not_includes response.body, 'flattened_grafana_dashboard'
      end

      test 'a variable that resolved to an empty string is named' do
        post admin_flatten_grafana_dashboard_path, params: { dashboard: upload(dashboard_json(value: '')) }

        assert_response :success
        assert_includes response.body, 'flatten-grafana-dashboard-empty-variables'
        assert_includes response.body, 'region_classification_tree'
      end

      test 'a v2beta1 export is refused with the version it carried' do
        post admin_flatten_grafana_dashboard_path, params: { dashboard: upload(dashboard_json(api_version: 'dashboard.grafana.app/v2beta1')) }

        assert_response :success
        assert_includes response.body, 'flatten-grafana-dashboard-error'
        assert_includes response.body, 'v2beta1'
        assert_not_includes response.body, 'flatten-grafana-dashboard-download'
      end

      test 'a file that is not JSON is refused' do
        post admin_flatten_grafana_dashboard_path, params: { dashboard: upload('<html></html>') }

        assert_response :success
        assert_includes response.body, 'flatten-grafana-dashboard-error'
      end

      # Valid JSON of the wrong shape used to reach the flattener and 500 inside the frame.
      test 'JSON that is not an object is refused like any other unusable upload' do
        ['[]', '[{"a":1}]', '123', 'null'].each do |content|
          post admin_flatten_grafana_dashboard_path, params: { dashboard: upload(content) }

          assert_response :success, "#{content} did not render the form"
          assert_includes response.body, 'flatten-grafana-dashboard-error'
        end
      end

      test 'a dashboard param that is not a file at all is refused' do
        post admin_flatten_grafana_dashboard_path, params: { dashboard: 'not-a-file' }

        assert_response :success
        assert_includes response.body, 'flatten-grafana-dashboard-error'
      end

      test 'a missing file is refused' do
        post admin_flatten_grafana_dashboard_path

        assert_response :success
        assert_includes response.body, 'flatten-grafana-dashboard-error'
      end

      test 'super_admin cannot rewrite a dashboard' do
        sign_in(User.find_by(email: 'admin@datacycle.at'))

        get admin_flatten_grafana_dashboard_form_path

        assert_response :redirect

        post admin_flatten_grafana_dashboard_path, params: { dashboard: upload(dashboard_json) }

        assert_response :redirect
      end

      private

      def upload(content)
        Rack::Test::UploadedFile.new(StringIO.new(content), 'application/json', original_filename: 'dashboard.json')
      end

      def downloaded_json_from(body)
        Base64.strict_decode64(body[%r{href="data:application/json;charset=utf-8;base64,([^"]+)"}, 1])
      end

      def dashboard_json(api_version: 'dashboard.grafana.app/v2', value: 'Administrative Einheiten')
        {
          'apiVersion' => api_version,
          'kind' => 'Dashboard',
          'metadata' => { 'name' => 'ot9m7zs', 'namespace' => 'default' },
          'spec' => {
            'title' => 'Analytics',
            'variables' => [
              {
                'kind' => 'ConstantVariable',
                'spec' => { 'name' => 'region_classification_tree', 'query' => value, 'current' => { 'text' => value, 'value' => value } }
              }
            ],
            'elements' => {
              'panel-1' => {
                'kind' => 'Panel',
                'spec' => {
                  'data' => {
                    'spec' => {
                      'queries' => [
                        { 'spec' => { 'query' => { 'spec' => { 'rawSql' => 'AND ctl.name = ${region_classification_tree:sqlstring}' } } } }
                      ]
                    }
                  }
                }
              }
            }
          }
        }.to_json
      end
    end
  end
end
