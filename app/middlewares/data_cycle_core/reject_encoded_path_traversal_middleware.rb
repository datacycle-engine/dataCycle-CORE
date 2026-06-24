# frozen_string_literal: true

module DataCycleCore
  # Middleware to reject requests with encoded path traversal attempts (%2e%2e or %252e%252e or ..).
  class RejectEncodedPathTraversalMiddleware
    ENCODED_TRAVERSAL_REGEX = /(%2e|%252e|\.){2}/i

    def initialize(app)
      @app = app
    end

    # Reject requests with encoded path traversal sequences early to prevent them from reaching controllers.
    def call(env)
      request_uri = env['REQUEST_URI'] || env['RAW_URI'] || env['REQUEST_PATH'] || env['PATH_INFO']

      return [404, { 'Content-Type' => 'text/plain' }, ['']] if request_uri&.match?(ENCODED_TRAVERSAL_REGEX)

      @app.call(env)
    end
  end
end
