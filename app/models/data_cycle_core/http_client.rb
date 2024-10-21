# frozen_string_literal: true

module DataCycleCore
  module HttpClient
    DEFAULT = {
      retry_options: {
        max: 3, interval: 30, backoff_factor: 2, retry_statuses: [503, 504]
      },
      follow_redirects: { limit: 5 },
      adapter: Faraday.default_adapter,
      timeout: 30
    }.freeze

    # Returns an HTTP client with the default configuration
    #
    # @yield [Faraday::Connection] a Faraday connection to customize further
    # @return [Faraday::Connection] a Faraday connection with the default configuration
    def self.default
      with_config { |conn|
        yield conn if block_given?
      }.dup
    end

    # Returns an HTTP client with the specified configuration. Defaults are used for unspecified options.
    #
    # @yield [Faraday::Connection] a Faraday connection to customize further
    #
    # @param config [Hash] a hash containing configuration options
    # - @option config [Integer] :timeout the timeout for the connection
    # - @option config [Hash] :retry_options options for the retry middleware
    # - @option config [Hash] :follow_redirects options for the follow redirects middleware
    # - @option config :adapter the adapter to use for the connection
    #
    # @return [Faraday::Connection] a Faraday connection with the specified configuration
    def self.with_config(**config, &)
      Faraday.default_connection.dup.tap { |conn|
        conn.adapter config[:adapter] || DEFAULT[:adapter]
        conn.options[:timeout] = config[:timeout] || DEFAULT[:timeout]
        conn.builder.handlers.delete(Faraday::Request::Retry)
        conn.request :retry, **DEFAULT[:retry_options].merge(config[:retry_options] || {})
        conn.builder.handlers.delete(FaradayMiddleware::FollowRedirects)
        conn.response :follow_redirects, **DEFAULT[:follow_redirects].merge(config[:follow_redirects] || {})
      }.tap do |conn|
        yield conn if block_given?
      end
    end
  end
end
