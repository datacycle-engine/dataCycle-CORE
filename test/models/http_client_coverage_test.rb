# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the HttpClient factory - with_config builds a Faraday connection with the
  # retry / follow-redirects middleware (merging caller overrides over the defaults) and
  # default delegates to it. Only the connection is built; no request is issued.
  class HttpClientCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'with_config builds a configured connection and yields it' do
      yielded = nil

      conn = DataCycleCore::HttpClient.with_config(timeout: 10, retry_options: { max: 5 }, follow_redirects: { limit: 2 }) do |connection|
        yielded = connection
      end

      assert_kind_of Faraday::Connection, conn
      assert_same conn, yielded
    end

    test 'default builds a connection with the default configuration and yields it' do
      yielded = nil

      conn = DataCycleCore::HttpClient.default { |connection| yielded = connection }

      assert_kind_of Faraday::Connection, conn
      assert_kind_of Faraday::Connection, yielded
    end
  end
end
