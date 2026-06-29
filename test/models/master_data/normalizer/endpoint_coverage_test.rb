# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    module Normalizer
      # Coverage for the Normalizer::Endpoint Faraday client. Faraday is stubbed with a
      # connection double whose #post yields a request double and returns a canned
      # response, so the request building, the success path and both error branches run
      # without any network access.
      class EndpointCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        Subject = DataCycleCore::MasterData::Normalizer::Endpoint

        def response_double(success:, body:)
          response = Object.new
          response.define_singleton_method(:success?) { success }
          response.define_singleton_method(:body) { body }
          response.define_singleton_method(:reason_phrase) { 'reason' }
          response.define_singleton_method(:status) { success ? 200 : 500 }
          response
        end

        def connection_double(response)
          request = Object.new
          request.define_singleton_method(:url) { |_url| nil }
          request.define_singleton_method(:headers) { @headers ||= {} }
          request.define_singleton_method(:body=) { |_body| nil }

          connection = Object.new
          connection.define_singleton_method(:post) do |&block|
            block.call(request)
            response
          end
          connection
        end

        test 'normalize returns early for a blank data list' do
          assert_nil Subject.new.normalize('id', nil)
          assert_nil Subject.new.normalize('id', [])
        end

        test 'normalize posts the data and returns the parsed response on success' do
          connection = connection_double(response_double(success: true, body: '{"status":"OK","result":42}'))

          result = Faraday.stub(:new, connection) do
            Subject.new.normalize(nil, [{ 'name' => 'x' }])
          end

          assert_equal 42, result['result']
        end

        test 'load_data raises an EndpointError on an unsuccessful response' do
          connection = connection_double(response_double(success: false, body: 'fail'))

          Faraday.stub(:new, connection) do
            assert_raises(DataCycleCore::Generic::Common::Error::EndpointError) do
              Subject.new.normalize('id', [{ 'name' => 'x' }])
            end
          end
        end

        test 'load_data raises an EndpointError when the status is not OK' do
          connection = connection_double(response_double(success: true, body: '{"status":"ERROR"}'))

          Faraday.stub(:new, connection) do
            assert_raises(DataCycleCore::Generic::Common::Error::EndpointError) do
              Subject.new.normalize('id', [{ 'name' => 'x' }])
            end
          end
        end
      end
    end
  end
end
