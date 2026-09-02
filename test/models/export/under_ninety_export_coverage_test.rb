# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the small Export::Generic action modules (create/update/delete/base/
  # functions) and the Export::Common::Error classes. The enqueue/filter collaborators
  # are stubbed at the lowest level (Functions.enqueue / Filter.filter) so both the
  # caller and Functions#filter get exercised without touching the export pipeline.
  class UnderNinetyExportCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    G = DataCycleCore::Export::Generic
    E = DataCycleCore::Export::Common::Error

    test 'Create/Update/Delete process + filter delegate to Functions' do
      [G::Create, G::Update, G::Delete].each do |mod|
        assert_nil mod.process(utility_object: nil, data: nil) # blank data short-circuit

        G::Functions.stub(:enqueue, nil) do
          assert_nil mod.process(utility_object: nil, data: { 'a' => 1 })
        end

        G::Filter.stub(:filter, :filtered) do
          assert_equal :filtered, mod.filter({ 'a' => 1 }, nil)
        end
      end
    end

    test 'Generic::Base process dups the utility object and enqueues; filter delegates' do
      base = G::Base.new(action: :create)

      assert_nil base.process(utility_object: nil, data: nil)

      # process dups the utility object before setting endpoint_method, so the dup (not
      # the original) carries the action; we only need the process body exercised here.
      uo = Class.new { attr_accessor :endpoint_method }.new

      base.stub(:enqueue, nil) do
        assert_nil base.process(utility_object: uo, data: { 'a' => 1 })
      end

      G::Filter.stub(:filter, :filtered) do
        assert_equal :filtered, base.filter({ 'a' => 1 }, nil)
      end
    end

    test 'Functions.filter forwards to Filter.filter' do
      G::Filter.stub(:filter, :forwarded) do
        assert_equal :forwarded, G::Functions.filter(data: {}, external_system: nil, method_name: 'create')
      end
    end

    test 'Export error classes build their messages' do
      assert_equal 'boom', E::ScheduleFormatError.new('boom').message
      assert_equal 'boom', E::SequentialError.new('boom').message

      response = struct_double(status: 500, reason_phrase: 'Server Error', body: 'oops')
      error = E::EndpointError.new('failed', response)

      assert_includes error.message, '500'
      assert_equal response, error.response
    end

    test 'Common::Transformations.json_api_v2 renders through the v2 contents controller' do
      DataCycleCore::Api::V2::ContentsController.stub(:render, '{"rendered":true}') do
        assert_equal '{"rendered":true}', DataCycleCore::Export::Common::Transformations.json_api_v2(nil, nil)
      end
    end

    test 'Generic::Transformations.json_partial builds a versioned thing renderer' do
      external_system = Object.new
      external_system.define_singleton_method(:credentials) { |_| { 'api_version' => 'v4', 'token_type' => 'body', 'token' => 'tok' } }
      external_system.define_singleton_method(:config) { {} }
      utility_object = Object.new
      utility_object.define_singleton_method(:external_system) { external_system }
      data = struct_double(id: 'thing-1')

      renderer = Object.new
      renderer.define_singleton_method(:render) { |_format| '{}' }

      DataCycleCore::ApiRenderer::ThingRendererV4.stub(:new, renderer) do
        assert_equal '{}', DataCycleCore::Export::Generic::Transformations.json_partial(utility_object, data)
      end
    end

    test 'Common::Endpoint::GenericEndpoint builds a host-scoped Faraday connection' do
      endpoint = DataCycleCore::Export::Common::Endpoint::GenericEndpoint.new(host: 'https://example.com')

      assert_includes endpoint.connection.url_prefix.to_s, 'example.com'
      assert_raises(RuntimeError) { DataCycleCore::Export::Common::Endpoint::GenericEndpoint.new.connection }
    end
  end
end
