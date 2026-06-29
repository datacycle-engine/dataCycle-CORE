# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Dashboard
    class DashBoardTest < ActionDispatch::IntegrationTest
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
        # default sign-in: super_admin, who must NOT have access to the computed-attributes feature
        sign_in(User.find_by(email: 'admin@datacycle.at'))
      end

      test 'admin dashboard' do
        get admin_path

        assert_response :success
      end

      test 'system_admin enqueues a job to update computed attributes (html fallback)' do
        sign_in(@system_admin)

        enqueued_args = nil
        DataCycleCore::RunTaskJob.stub(:perform_later, ->(*args) { enqueued_args = args }) do
          post admin_update_computed_attributes_path, params: { templates_or_collection_id: 'Image', webhooks: 'false', computed_name: ['slug'] }
        end

        assert_redirected_to admin_path
        assert_equal ['dc:update_data:computed_attributes', ['Image', false, 'slug']], enqueued_args
      end

      test 'system_admin enqueues a job and refreshes the dashboard via turbo_stream without reloading' do
        sign_in(@system_admin)

        enqueued_args = nil
        DataCycleCore::RunTaskJob.stub(:perform_later, ->(*args) { enqueued_args = args }) do
          post admin_update_computed_attributes_path,
               params: { templates_or_collection_id: 'Image', webhooks: 'false', computed_name: ['slug'] },
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        end

        assert_response :success
        assert_equal 'text/vnd.turbo-stream.html', response.media_type
        assert_equal ['dc:update_data:computed_attributes', ['Image', false, 'slug']], enqueued_args
        # streams the flash and refreshes the job queue in place instead of redirecting
        assert_includes response.body, 'target="flash-messages"'
        assert_includes response.body, 'target="jobs_queue_title"'
        assert_includes response.body, 'target="jobs_queue_body"'
      end

      test 'system_admin does not enqueue a job when no computed attribute is selected' do
        sign_in(@system_admin)

        enqueued = false
        DataCycleCore::RunTaskJob.stub(:perform_later, ->(*_args) { enqueued = true }) do
          post admin_update_computed_attributes_path, params: { templates_or_collection_id: 'Image', computed_name: [''] }
        end

        assert_not enqueued
      end

      test 'system_admin gets a turbo_stream error flash when input is missing' do
        sign_in(@system_admin)

        enqueued = false
        DataCycleCore::RunTaskJob.stub(:perform_later, ->(*_args) { enqueued = true }) do
          post admin_update_computed_attributes_path,
               params: { templates_or_collection_id: 'Image', computed_name: [''] },
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        end

        assert_not enqueued
        assert_response :success
        assert_equal 'text/vnd.turbo-stream.html', response.media_type
        assert_includes response.body, 'target="flash-messages"'
      end

      test 'system_admin lazily renders the computed attributes form turbo-frame' do
        sign_in(@system_admin)

        get admin_computed_attributes_form_path

        assert_response :success
        assert_includes response.body, 'turbo-frame'
        assert_includes response.body, 'admin_dashboard_computed_attributes_form'
        assert_includes response.body, 'update-computed-attributes-form'
      end

      test 'super_admin cannot access the computed attributes feature' do
        get admin_computed_attributes_form_path

        assert_response :redirect

        enqueued = false
        DataCycleCore::RunTaskJob.stub(:perform_later, ->(*_args) { enqueued = true }) do
          post admin_update_computed_attributes_path, params: { templates_or_collection_id: 'Image', computed_name: ['slug'] }
        end

        assert_not enqueued
      end
    end
  end
end
