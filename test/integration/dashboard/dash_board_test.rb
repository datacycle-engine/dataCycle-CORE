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

      test 'pg_stats renders the database statistics' do
        get admin_pg_stats_path

        assert_response :success
      end

      # Enqueuing/destroying jobs fires after_enqueue/after_destroy_commit dashboard
      # broadcasts (Turbo::Throttler) that loop/raise inside the test harness; stub them out.
      def without_job_broadcasts(&)
        DataCycleCore::StatsJobQueue.stub(:broadcast_throttled_jobs_reload, nil) do
          DataCycleCore::StatsJobQueue.stub(:broadcast_jobs_reload, nil, &)
        end
      end

      # The import jobs run inline in the test adapter and their #perform requires keyword
      # args the controller doesn't pass; stub the job builder with a no-op double so only
      # the controller's enqueue branch is exercised.
      def fake_dashboard_job
        job = Object.new
        def job.queue_name = 'importers'
        def job.delayed_reference_type = 'DataCycleCore::ExternalSystem'
        def job.delayed_reference_id = SecureRandom.uuid
        # enqueue's return value is unused by the controller
        def job.enqueue = nil
        job
      end

      test 'download enqueues a download job and redirects' do
        external_source = DataCycleCore::ExternalSystem.first

        DataCycleCore::DownloadJob.stub(:new, fake_dashboard_job) do
          post admin_download_path(external_source.id), params: { mode: 'full' }
        end

        assert_response :redirect
      end

      test 'download reports a running job when one is already queued' do
        external_source = DataCycleCore::ExternalSystem.first

        DataCycleCore::DownloadJob.stub(:new, fake_dashboard_job) do
          Delayed::Job.stub(:exists?, true) do
            post admin_download_path(external_source.id), params: { mode: 'full' }
          end
        end

        assert_response :redirect
      end

      test 'import enqueues an import-only job and refreshes via turbo_stream' do
        external_source = DataCycleCore::ExternalSystem.first

        DataCycleCore::ImportOnlyJob.stub(:new, fake_dashboard_job) do
          post admin_import_path(external_source.id), params: { mode: 'incremental' }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        end

        assert_response :success
        assert_equal 'text/vnd.turbo-stream.html', response.media_type
        assert_includes response.body, 'target="jobs_queue_title"'
      end

      test 'download_import enqueues a combined job and redirects' do
        external_source = DataCycleCore::ExternalSystem.first

        DataCycleCore::ImportJob.stub(:new, fake_dashboard_job) do
          post admin_download_import_path(external_source.id), params: { mode: 'full' }
        end

        assert_response :redirect
      end

      test 'delete_queue destroys a delayed job' do
        wrapper = ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.new(DataCycleCore::RebuildClassificationMappingsJob.new.serialize)
        job = Delayed::Job.create!(handler: wrapper.to_yaml, queue: 'default')

        without_job_broadcasts do
          delete admin_delete_queue_path(job.id)
        end

        assert_response :redirect
        assert_not Delayed::Job.exists?(job.id)
      end

      test 'rebuild_classification_mappings queues a job and redirects (html)' do
        DataCycleCore::RebuildClassificationMappingsJob.stub(:perform_later, nil) do
          post admin_rebuild_classification_mappings_path
        end

        assert_redirected_to admin_path
      end

      test 'rebuild_classification_mappings queues a job and refreshes via turbo_stream' do
        DataCycleCore::RebuildClassificationMappingsJob.stub(:perform_later, nil) do
          post admin_rebuild_classification_mappings_path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        end

        assert_response :success
        assert_equal 'text/vnd.turbo-stream.html', response.media_type
        assert_includes response.body, 'target="flash-messages"'
      end

      test 'import_module renders mongo statistics for an external source' do
        external_source = DataCycleCore::ExternalSystem.first

        get admin_import_module_path, params: { id: external_source.id }

        assert_response :success
      end

      test 'activity_details returns json for each supported type' do
        ['summary', 'user_summary', 'details'].each do |type|
          get admin_activity_details_path(type)

          assert_response :success
          assert response.parsed_body.key?('data')
        end
      end

      test 'activity_details returns an error for an unknown type' do
        get admin_activity_details_path('bogus')

        assert_response :success
        assert response.parsed_body.key?('error')
      end
    end
  end
end
