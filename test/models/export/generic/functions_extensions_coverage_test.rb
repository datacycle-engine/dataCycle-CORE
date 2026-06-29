# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the Export::Generic::FunctionsExtensions webhook-enqueue mixin,
  # exercised through a host object that includes it and lightweight doubles for the
  # utility object / webhook job / external system (no real export pipeline needed).
  class ExportFunctionsExtensionsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def host
      @host ||= Class.new { include DataCycleCore::Export::Generic::FunctionsExtensions }.new
    end

    # minimal stand-in object responding to the given attributes (and nothing else, so
    # #try returns nil for absent methods)
    def dbl(**attrs)
      obj = Object.new
      attrs.each { |k, v| obj.define_singleton_method(k) { v } }
      obj
    end

    # records every set/perform_now/perform_later call; #set returns self (chainable)
    def webhook_double
      calls = []
      webhook = Object.new
      webhook.define_singleton_method(:set) do |**kw|
        calls << [:set, kw]
        webhook
      end
      webhook.define_singleton_method(:perform_now) { |**kw| calls << [:perform_now, kw] }
      webhook.define_singleton_method(:perform_later) { |**kw| calls << [:perform_later, kw] }
      webhook.define_singleton_method(:calls) { calls }
      webhook
    end

    def utility_object_double(webhook:, external_system:, wait_time: nil)
      uo = Object.new
      uo.define_singleton_method(:external_system) { external_system }
      uo.define_singleton_method(:webhook_job_class) { webhook }
      uo.define_singleton_method(:wait_time) { wait_time }
      uo.define_singleton_method(:action) { :create }
      uo.define_singleton_method(:filter_checked?) { true }
      uo.define_singleton_method(:type) { 'thing' }
      uo.define_singleton_method(:path) { '/path' }
      uo.define_singleton_method(:endpoint_method) { 'method' }
      uo.define_singleton_method(:transformation) { 'transform' }
      uo
    end

    # --- synchronous_webhooks? --------------------------------------------------------

    test 'synchronous_webhooks? is true when the data flags it' do
      uo = dbl(external_system: dbl(export_config: {}), action: :create)

      assert host.synchronous_webhooks?(dbl(synchronous_webhooks: true), uo)
    end

    test 'synchronous_webhooks? honours the per-action and the global inline queue config' do
      per_action = dbl(external_system: dbl(export_config: { create: { queue: 'inline' } }), action: :create)
      global = dbl(external_system: dbl(export_config: { queue: 'inline' }), action: :create)
      neither = dbl(external_system: dbl(export_config: {}), action: :create)

      assert host.synchronous_webhooks?(Object.new, per_action)
      assert host.synchronous_webhooks?(Object.new, global)
      assert_not host.synchronous_webhooks?(Object.new, neither)
    end

    # --- apply_webhook_params! --------------------------------------------------------

    test 'apply_webhook_params! sets wait_until and priority on the webhook' do
      webhook = webhook_double
      host.apply_webhook_params!(webhook, dbl(webhook_run_at: nil, webhook_priority: 3))

      assert_equal [:set], webhook.calls.map(&:first)
      params = webhook.calls.first.last

      assert params.key?(:wait_until)
      assert_equal 3, params[:priority]
    end

    # --- append_thing_data! -----------------------------------------------------------

    test 'append_thing_data! collects optional attributes and webhook accessors for non-Thing data' do
      data_class = Class.new do
        def template_name = 'Artikel'
        def original_id = 'orig'
        def duplicate_id = 'dup'
        def additional_webhook_attributes = ['extra']
        def extra = 'extra-value'
        def acc = 'acc-value'
      end
      data_class.const_set(:WEBHOOK_ACCESSORS, ['acc'])

      data_object = {}
      host.append_thing_data!(data_object, data_class.new, dbl(id: 'es-1'))

      assert_equal 'Artikel', data_object[:template_name]
      assert_equal 'orig', data_object[:original_id]
      assert_equal 'dup', data_object[:duplicate_id]
      assert_equal 'extra-value', data_object[:extra]
      assert_equal 'acc-value', data_object[:acc]
    end

    test 'append_thing_data! merges webhook_data and external keys for a Thing' do
      thing = DataCycleCore::Thing.new(template_name: 'Artikel')
      data_object = {}
      host.append_thing_data!(data_object, thing, dbl(id: 'es-1'))

      assert_equal 'Artikel', data_object[:template_name]
      assert data_object.key?(:webhook_data)
      assert data_object[:webhook_data].key?(:external_keys)
    end

    # --- enqueue ----------------------------------------------------------------------

    test 'enqueue dispatches the webhook synchronously with the assembled payload' do
      webhook = webhook_double
      external_system = dbl(id: 'es-1', export_config: { create: { queue: 'inline' } })
      data = dbl(id: 'thing-1', template_name: 'Artikel')
      uo = utility_object_double(webhook:, external_system:, wait_time: 5)

      host.enqueue(utility_object: uo, data:)

      dispatched = webhook.calls.find { |c| c.first == :perform_now }

      assert dispatched
      payload = dispatched.last

      assert_equal :create, payload[:action]
      assert_equal 'es-1', payload[:external_system_id]
      assert_equal 'thing', payload[:type]
      assert_equal 'Artikel', payload[:data_object][:template_name]
    end
  end
end
