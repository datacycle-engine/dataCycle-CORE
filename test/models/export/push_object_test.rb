# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Export
    # minimal endpoint double resolved via export_config['endpoint']
    class PushObjectTestEndpoint
      def initialize(**opts)
        @opts = opts
      end

      def content_request(utility_object:, data:) # rubocop:disable Lint/UnusedMethodArgument
        :content_sent
      end

      def custom_request(utility_object:, data:) # rubocop:disable Lint/UnusedMethodArgument
        :custom_sent
      end
    end

    class PushObjectTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @external_system = DataCycleCore::ExternalSystem.create!(
          name: 'PushObject ES',
          credentials: { 'export' => {} },
          config: {
            'export_config' => {
              'create' => { 'method' => 'put', 'transformation' => 'xml', 'path' => 'items/%<id>s', 'endpoint_method' => 'custom_request', 'destroy_failed_jobs' => true },
              'endpoint' => 'DataCycleCore::Export::PushObjectTestEndpoint',
              'allowed_models' => 'DataCycleCore::Thing',
              'method' => 'post'
            }
          }
        )
        @thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'PushObject Thing' })
      end

      def build_push_object(action: :create, **)
        DataCycleCore::Export::PushObject.new(action:, external_system: @external_system, **)
      end

      test 'initialize resolves the external system from an instance and assigns kwargs' do
        pobj = DataCycleCore::Export::PushObject.new(
          action: 'create', external_system: @external_system,
          locale: 'en', filter_checked: true, type: 't', path: 'p', endpoint_method: 'm', transformation: 'xml'
        )

        assert_equal(:create, pobj.action)
        assert_equal('en', pobj.locale)
        assert_equal(@external_system, pobj.external_system)
        assert_predicate(pobj, :filter_checked?)
      end

      test 'initialize resolves the external system from a uuid id' do
        pobj = DataCycleCore::Export::PushObject.new(action: :create, external_system_id: @external_system.id)

        assert_equal(@external_system.id, pobj.external_system.id)
      end

      test 'initialize raises without an external system' do
        assert_raises(ActiveModel::MissingAttributeError) do
          DataCycleCore::Export::PushObject.new(action: :create)
        end
      end

      test 'webhook_valid? checks export config, action and allowed models' do
        blank_es = DataCycleCore::ExternalSystem.new(name: 'blank', config: { 'export_config' => {} })

        assert_not(DataCycleCore::Export::PushObject.new(action: :create, external_system: blank_es).webhook_valid?(@thing))
        assert_not(build_push_object(action: :update).webhook_valid?(@thing))
        assert(build_push_object(action: :create).webhook_valid?(@thing))
      end

      test 'allowed? marks filter-checked and delegates to the webhook' do
        pobj = build_push_object
        fake = Object.new
        # `filter` mirrors the webhook strategy interface, so it cannot be renamed to a predicate
        def fake.filter(_data, _external_system) = true # rubocop:disable Naming/PredicateMethod

        result = pobj.stub(:webhook, fake) { pobj.allowed?(@thing) }

        assert(result)
        assert_predicate(pobj, :filter_checked?)

        nil_hook = build_push_object

        assert_not(nil_hook.stub(:webhook, nil) { nil_hook.allowed?(@thing) })
      end

      test 'process delegates to the webhook unless it is missing' do
        pobj = build_push_object
        fake = Object.new
        def fake.process(data:, utility_object:) = :processed # rubocop:disable Lint/UnusedMethodArgument

        assert_equal(:processed, pobj.stub(:webhook, fake) { pobj.process(@thing) })
        assert_nil(pobj.stub(:webhook, nil) { pobj.process(@thing) })
      end

      test 'delete_action? and synchronous_filter?' do
        assert_predicate(build_push_object(action: :delete), :delete_action?)
        assert_not(build_push_object(action: :create).delete_action?)
        assert(build_push_object(action: :delete).synchronous_filter?(@thing))
      end

      test 'discard_job_on_failure? reads the export config flags' do
        assert_predicate(build_push_object(action: :create), :discard_job_on_failure?)
      end

      test 'http_method falls back through config and defaults' do
        assert_equal(:put, build_push_object(action: :create).http_method)
      end

      test 'transformation and webhook_job_class fall back through config and defaults' do
        assert_equal(:xml, build_push_object(action: :create).transformation)
        assert_equal(DataCycleCore::WebhookJob, build_push_object(action: :create).webhook_job_class)
      end

      test 'webhook returns nil for an unconfigured action and a strategy otherwise' do
        assert_nil(build_push_object(action: :update).webhook)
        assert_kind_of(DataCycleCore::Export::Generic::Base, build_push_object(action: :create).webhook)
      end

      test 'transformed_path formats the configured path template' do
        assert_equal("items/#{@thing.id}", build_push_object(action: :create).transformed_path(@thing))
      end

      test 'transformed_path delegates to the endpoint when it supports path_transformation' do
        pobj = build_push_object(action: :create)
        endpoint = Object.new
        def endpoint.path_transformation(_data, _external_system, _action, _type, _path) = 'transformed/path'

        assert_equal('transformed/path', pobj.stub(:endpoint, endpoint) { pobj.transformed_path(@thing) })
      end

      test 'endpoint instantiates the configured endpoint class' do
        assert_kind_of(DataCycleCore::Export::PushObjectTestEndpoint, build_push_object(action: :create).endpoint)
      end

      test 'send_request resolves the endpoint method and calls the endpoint' do
        assert_equal(:custom_sent, build_push_object(action: :create).send_request(@thing))
      end
    end
  end
end
