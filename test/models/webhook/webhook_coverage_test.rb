# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Webhook
    # Coverage for the webhook dispatch layer: Webhook::Base (execute / execute_all /
    # webhooks_for / utility_object_for), Webhook::Deploy and the Generic::Common
    # LoggingWebhook / Webhook strategy objects. Collaborators (PushObject, the
    # Download/Import pipeline, ExternalSystem lookups) are stubbed so the control
    # flow runs without a real export target or Mongo.
    class WebhookCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # --- Webhook::Base ----------------------------------------------------
      test 'Base.execute skips filtered delete hooks and processes the rest' do
        filtered = Object.new
        filtered.define_singleton_method(:synchronous_filter?) { |_| true }
        filtered.define_singleton_method(:allowed?) { |_| false }

        assert_nil DataCycleCore::Webhook::Base.execute(filtered, {})

        processed = false
        active = Object.new
        active.define_singleton_method(:synchronous_filter?) { |_| false }
        active.define_singleton_method(:allowed?) { |_| true }
        active.define_singleton_method(:process) { |_| processed = true }

        DataCycleCore::Webhook::Base.execute(active, {})

        assert processed
      end

      test 'Base.execute_all returns early when webhooks are prevented' do
        data = struct_double(prevent_webhooks: true)

        assert_nil DataCycleCore::Webhook::Base.execute_all(data, 'update')
      end

      test 'Base.execute_all instruments a failing hook without raising' do
        utility_object = Object.new
        instrumented = nil

        DataCycleCore::Webhook::Base.stub(:webhooks_for, ->(*) { [utility_object] }) do
          DataCycleCore::Webhook::Base.stub(:execute, ->(*) { raise SystemStackError }) do
            ActiveSupport::Notifications.stub(:instrument, ->(name, _payload = {}) { instrumented = name }) do
              DataCycleCore::Webhook::Base.execute_all(Object.new, 'update')
            end
          end
        end

        assert_equal 'webhooks_failed.datacycle', instrumented
      end

      test 'Base.webhooks_for maps matching external systems through utility_object_for' do
        external_system_name = DataCycleCore::ExternalSystem.first.name

        DataCycleCore::Webhook::Base.stub(:available_system_names, ->(*) { [external_system_name] }) do
          calls = 0
          DataCycleCore::Webhook::Base.stub(:utility_object_for, lambda { |*|
            calls += 1
            nil
          }) do
            assert_empty DataCycleCore::Webhook::Base.webhooks_for('update', Object.new)
            assert_operator calls, :>=, 1
          end
        end
      end

      test 'Base.utility_object_for returns the push object only when the webhook is valid' do
        valid = Object.new
        valid.define_singleton_method(:webhook_valid?) { |_| true }

        DataCycleCore::Export::PushObject.stub(:new, valid) do
          assert_equal valid, DataCycleCore::Webhook::Base.utility_object_for('es', 'update', {})
        end

        invalid = Object.new
        invalid.define_singleton_method(:webhook_valid?) { |_| false }

        DataCycleCore::Export::PushObject.stub(:new, invalid) do
          assert_nil DataCycleCore::Webhook::Base.utility_object_for('es', 'update', {})
        end
      end

      # --- Webhook::Deploy --------------------------------------------------
      test 'Deploy.execute_all delegates to Base with the deploy action' do
        captured = nil
        DataCycleCore::Webhook::Base.stub(:execute_all, ->(_data, action, **) { captured = action }) do
          DataCycleCore::Webhook::Deploy.execute_all({})
        end

        assert_equal 'deploy', captured
      end

      test 'Deploy.deployable? checks that a deploy hook allows the data' do
        hook = Object.new
        hook.define_singleton_method(:allowed?) { |_| true }

        DataCycleCore::Webhook::Deploy.stub(:webhooks_for, ->(*) { [hook] }) do
          assert DataCycleCore::Webhook::Deploy.deployable?({})
        end

        DataCycleCore::Webhook::Deploy.stub(:webhooks_for, ->(*) { [] }) do
          assert_not DataCycleCore::Webhook::Deploy.deployable?({})
        end
      end

      # --- Generic::Common::LoggingWebhook ----------------------------------
      test 'LoggingWebhook logs an activity and strips internal keys on every action' do
        webhook = DataCycleCore::Generic::Common::LoggingWebhook.new(nil, nil, nil, nil)
        data = { 'controller' => 'contents', 'action' => 'update', 'format' => 'json', 'external_source_id' => 'x', 'payload' => 'keep' }

        result = webhook.update(data, nil)

        assert_equal({ 'payload' => 'keep' }, result)
        assert_kind_of Hash, webhook.create(data, nil)
        assert_kind_of Hash, webhook.delete(data, nil)
      end

      # --- Generic::Common::Webhook -----------------------------------------
      test 'Generic::Common::Webhook raises NotImplementedError for the crud hooks' do
        webhook = DataCycleCore::Generic::Common::Webhook.new(nil, nil, nil, nil)

        assert_raises(NotImplementedError) { webhook.update(nil, nil) }
        assert_raises(NotImplementedError) { webhook.create(nil, nil) }
        assert_raises(NotImplementedError) { webhook.delete(nil, nil) }
      end

      test 'Generic::Common::Webhook#download_content builds the download pipeline' do
        external_source = struct_double(default_options: {})
        webhook = DataCycleCore::Generic::Common::Webhook.new(external_source, nil, nil, nil)

        assert_nil webhook.download_content(download_config: nil, data_name: nil, data: nil)

        download_config = { 'items' => { 'download_strategy' => 'DataCycleCore::Generic::Common::DownloadConceptsFromYaml' } }
        forwarded = nil

        DataCycleCore::Generic::DownloadObject.stub(:new, Object.new) do
          DataCycleCore::Generic::Common::DownloadFunctions.stub(:download_single, ->(**kwargs) { forwarded = kwargs }) do
            webhook.download_content(download_config:, data_name: 'items', data: { 'a' => 1 })
          end
        end

        assert forwarded.key?(:data_id)
        assert forwarded.key?(:data_name)
      end

      test 'Generic::Common::Webhook#import_content builds the import pipeline' do
        external_source = struct_double(default_options: {})
        webhook = DataCycleCore::Generic::Common::Webhook.new(external_source, nil, nil, nil)

        assert_nil webhook.import_content(import_config: nil, data_name: nil, data: nil, locale: nil)

        import_config = { 'items' => { 'import_strategy' => 'DataCycleCore::Generic::Common::ImportContents' } }
        processed = false

        DataCycleCore::Generic::ImportObject.stub(:new, Object.new) do
          DataCycleCore::Generic::Common::ImportContents.stub(:process_content, ->(**) { processed = true }) do
            webhook.import_content(import_config:, data_name: 'items', data: { 'a' => 1 }, locale: 'de')
          end
        end

        assert processed
      end
    end
  end
end
