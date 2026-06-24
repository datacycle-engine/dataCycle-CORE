# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class WebhookJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    class FakeWebhookItem
      WEBHOOK_ACCESSORS = [:foo].freeze
      attr_accessor :foo, :original_id

      def self.find_by(id:)
        _ = id
        new
      end
    end

    def sync_double
      sync = Object.new
      updates = []
      sync.define_singleton_method(:update) { |**attrs| updates << attrs }
      sync.define_singleton_method(:updates) { updates }
      sync.define_singleton_method(:data) { {} }
      sync
    end

    def utility_double(action: :update, discard: true)
      external_system = Object.new
      external_system.define_singleton_method(:name) { 'Webhook System' }

      utility = Object.new
      utility.define_singleton_method(:external_system) { external_system }
      utility.define_singleton_method(:action) { action }
      utility.define_singleton_method(:endpoint_method) { 'POST' }
      utility.define_singleton_method(:discard_job_on_failure?) { discard }
      utility.define_singleton_method(:filter_checked?) { false }
      utility.define_singleton_method(:allowed?) { |_data| false }
      utility.define_singleton_method(:send_request) { |_data| :response }
      utility
    end

    def data_double(sync:)
      data = Object.new
      data.define_singleton_method(:external_system_sync_by_system) do |external_system:|
        _ = external_system
        sync
      end
      data.define_singleton_method(:id) { 'data-1' }
      data
    end

    def build_job(args = { data_object: { id: 1 }, external_system_id: 'es', action: :update })
      DataCycleCore::WebhookJob.new(args)
    end

    test 'reference id and type are derived from the arguments' do
      job = build_job

      assert_equal 1, job.delayed_reference_id
      assert_equal 'es_update', job.delayed_reference_type
    end

    test 'discard_on_failure delegates to the utility object' do
      job = build_job
      job.instance_variable_set(:@utility_object, utility_double(discard: true))

      assert_predicate job, :discard_on_failure?
    end

    test 'perform sends the request through the utility object' do
      job = build_job
      job.instance_variable_set(:@utility_object, utility_double)
      job.instance_variable_set(:@data, data_double(sync: sync_double))

      job.perform

      assert_equal :response, job.response
    end

    test 'init_external_sync marks the sync as pending and instruments the start' do
      job = build_job
      sync = sync_double
      job.instance_variable_set(:@utility_object, utility_double)
      job.instance_variable_set(:@data, data_double(sync:))

      job.init_external_sync

      assert_equal 'pending', sync.updates.first[:status]
    end

    test 'success_external_sync marks the sync as successful' do
      job = build_job
      sync = sync_double
      job.instance_variable_set(:@utility_object, utility_double)
      job.instance_variable_set(:@external_sync, sync)
      job.instance_variable_set(:@start_time, Time.zone.now)

      job.success_external_sync

      assert_equal 'success', sync.updates.first[:status]
    end

    test 'success_delete flags duplicates for delete actions' do
      job = build_job
      sync = sync_double
      job.instance_variable_set(:@utility_object, utility_double(action: :delete))
      job.instance_variable_set(:@external_sync, sync)

      job.success_delete

      assert_equal 'duplicate', sync.updates.first[:sync_type]
    end

    test 'success_delete does nothing for non-delete actions' do
      job = build_job
      sync = sync_double
      job.instance_variable_set(:@utility_object, utility_double(action: :update))
      job.instance_variable_set(:@external_sync, sync)

      job.success_delete

      assert_empty sync.updates
    end

    test 'error_external_sync records the error and exception data' do
      job = build_job
      sync = sync_double
      job.instance_variable_set(:@utility_object, utility_double)
      job.instance_variable_set(:@external_sync, sync)
      job.last_error = StandardError.new('kaputt')

      job.error_external_sync

      assert_equal 'error', sync.updates.first[:status]
    end

    test 'failure_external_sync records the failure and exception data' do
      job = build_job
      sync = sync_double
      error = StandardError.new('kaputt')
      error.set_backtrace(['a.rb:1', 'b.rb:2'])
      job.instance_variable_set(:@utility_object, utility_double)
      job.instance_variable_set(:@external_sync, sync)
      job.last_error = error

      job.failure_external_sync

      assert_equal 'failure', sync.updates.first[:status]
    end

    test 'initialize_context aborts for blank arguments' do
      job = DataCycleCore::WebhookJob.new

      assert_throws(:abort) { job.initialize_context }
    end

    test 'initialize_context builds the data item and utility object' do
      args = { data_object: { klass: nil, id: 1, webhook_data: { x: 1 }, original_id: 5 }, action: :delete, external_system_id: 'es' }
      job = DataCycleCore::WebhookJob.new(args)
      utility = utility_double(action: :delete)

      DataCycleCore::Export::PushObject.stub(:new, utility) do
        job.initialize_context
      end

      assert_equal utility, job.utility_object
      assert_equal 5, job.data.original_id
    end

    test 'initialize_context aborts on a missing attribute error' do
      args = { data_object: { klass: nil, id: 1 }, action: :delete }
      job = DataCycleCore::WebhookJob.new(args)

      DataCycleCore::Export::PushObject.stub(:new, ->(**_kwargs) { raise ActiveModel::MissingAttributeError, 'missing' }) do
        assert_throws(:abort) { job.initialize_context }
      end
    end

    test 'parse_data_item aborts when the item is missing for create or update actions' do
      job = DataCycleCore::WebhookJob.new({ data_object: { klass: nil, id: 1 }, action: :create })

      assert_throws(:abort) { job.send(:parse_data_item, { klass: nil, id: 1 }) }
    end

    test 'parse_data_item assigns webhook accessors when the class defines them' do
      job = DataCycleCore::WebhookJob.new({ data_object: {}, action: :update })

      item = job.send(:parse_data_item, { klass: 'DataCycleCore::WebhookJobTest::FakeWebhookItem', id: 1, foo: 'bar' })

      assert_equal 'bar', item.foo
    end

    test 'check_filter aborts when the webhook is neither pre-checked nor allowed' do
      job = build_job
      job.instance_variable_set(:@utility_object, utility_double)
      job.instance_variable_set(:@data, data_double(sync: sync_double))

      assert_throws(:abort) { job.check_filter }
    end
  end
end
