# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Export
    module Generic
      # Coverage for the export webhook endpoint (Export::Generic::Endpoint).
      # content_request is pure orchestration over the utility_object/data collaborators
      # and Faraday, so it is exercised with lightweight doubles and a stubbed
      # Faraday.run_request / LogFile.new (no HTTP, no disk).
      class EndpointTest < DataCycleCore::TestCases::ActiveSupportTestCase
        SUBJECT = DataCycleCore::Export::Generic::Endpoint

        # Stands in for Generic::Logger::LogFile (records calls, no disk I/O).
        class LogDouble
          attr_reader :infos, :errors

          def initialize
            @infos = []
            @errors = []
          end

          def info(*args)
            @infos << args
          end

          def error(*args)
            @errors << args
          end

          def close
            nil
          end
        end

        # The request object Faraday yields to the configuration block.
        Req = Struct.new(:params, :headers, :options)

        def response_double
          Struct.new(:env, :body).new(
            { method: :post, url: 'http://example.test/things/1', status: 200, reason_phrase: 'OK' },
            '{"ok":true}'
          )
        end

        # PushObject-shaped collaborator; external_system credentials are configurable.
        def utility_object(transformation:, credentials: nil)
          external_system = Class.new {
            def initialize(creds)
              @creds = creds
            end

            def name
              'Test ES'
            end

            def credentials(_type)
              @creds
            end
          }.new(credentials)

          Class.new {
            def initialize(external_system, transformation)
              @external_system = external_system
              @transformation = transformation
            end

            attr_reader :external_system, :transformation

            def http_method
              :post
            end

            def transformed_path(_data)
              'things/1'
            end
          }.new(external_system, transformation)
        end

        # data-shaped collaborator; external_system_sync_by_system returns the given ess.
        def data_double(ess: nil)
          Class.new {
            def initialize(ess)
              @ess = ess
            end

            def id
              'data-id-1'
            end

            def external_system_sync_by_system(external_system:) # rubocop:disable Lint/UnusedMethodArgument
              @ess
            end
          }.new(ess)
        end

        # Runs content_request with LogFile.new + Faraday.run_request stubbed.
        # The Faraday stub yields a fresh Req to the configuration block (so the
        # token/header/option setup runs) and returns response_double.
        def run_content_request(endpoint, utility_object:, data:)
          faraday = lambda { |*_args, &blk|
            blk&.call(Req.new({}, {}, {}))
            response_double
          }
          result = nil
          DataCycleCore::Generic::Logger::LogFile.stub(:new, LogDouble.new) do
            Faraday.stub(:run_request, faraday) do
              result = endpoint.content_request(utility_object:, data:)
            end
          end
          result
        end

        test 'transformations exposes the Transformations module' do
          assert_equal DataCycleCore::Export::Generic::Transformations, SUBJECT.new.transformations
        end

        test 'initialize defaults token_type to body' do
          endpoint = SUBJECT.new(host: 'http://example.test', token: 'abc')

          assert_equal 'body', endpoint.instance_variable_get(:@token_type)
          assert_equal 'http://example.test', endpoint.instance_variable_get(:@host)
        end

        test 'content_request with a module transformation, url token and full credentials' do
          mod = Module.new do
            def self.transform(_utility_object, _data)
              { 'payload' => 1 }
            end
          end
          ess = Class.new {
            attr_reader :exported

            def update(exported_data:)
              @exported = exported_data
            end
          }.new
          utility_object = utility_object(
            transformation: { module: mod, method: :transform },
            credentials: { 'additional_headers' => { 'X-Custom' => '1' }, 'faraday_options' => { 'timeout' => 5 } }
          )
          endpoint = SUBJECT.new(host: 'http://example.test', token: 'tok-123', token_type: 'url')

          response = run_content_request(endpoint, utility_object:, data: data_double(ess:))

          assert_equal 200, response.env[:status]
          assert_equal({ 'payload' => 1 }, ess.exported)
        end

        test 'content_request with a proc transformation returning JSON, http_headers token, no ess' do
          utility_object = utility_object(transformation: ->(_utility_object, _data) { '{"x":1}' })
          endpoint = SUBJECT.new(host: 'http://example.test', token: { 'X-Tok' => 'v' }, token_type: 'http_headers')

          response = run_content_request(endpoint, utility_object:, data: data_double)

          assert_equal 200, response.env[:status]
        end

        test 'content_request with a symbol transformation (try), x_api_key token, nil body' do
          # An unknown method name makes transformations.try(...) return nil, so the
          # JSON.parse(nil) path hits the rescue modifier and exported_data stays nil.
          utility_object = utility_object(transformation: :__not_a_transformation__)
          endpoint = SUBJECT.new(host: 'http://example.test', token: 'api-key', token_type: 'x_api_key')

          response = run_content_request(endpoint, utility_object:, data: data_double)

          assert_equal 200, response.env[:status]
        end

        test 'content_request wraps Faraday errors in a WebhookError' do
          utility_object = utility_object(transformation: ->(_utility_object, _data) { { 'a' => 1 } })
          faraday = ->(*_args, &_blk) { raise Faraday::ConnectionFailed, 'boom' }
          endpoint = SUBJECT.new(host: 'http://example.test')

          assert_raises(DataCycleCore::Error::WebhookError) do
            DataCycleCore::Generic::Logger::LogFile.stub(:new, LogDouble.new) do
              Faraday.stub(:run_request, faraday) do
                endpoint.content_request(utility_object:, data: data_double)
              end
            end
          end
        end
      end
    end
  end
end
