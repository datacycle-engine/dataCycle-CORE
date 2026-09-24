# frozen_string_literal: true

module DataCycleCore
  # Handing a Rack response of the MCP transport over to Rails. Shared by both mounts
  # (Api::Mcp::McpController global, Api::V4::McpController endpoint-scoped): the block used to sit
  # there twice word for word and therefore carried the same bug twice.
  #
  # Both mounts build the transport with `stateless: true`, and that is not a detail: otherwise
  # StreamableHTTPTransport keeps session and SSE state in process memory and thereby requires
  # `workers 0` -- under Puma's multi-worker setup a follow-up request lands in the wrong worker.
  # Stateless also makes handle_request ALWAYS return a single JSON response instead of an SSE
  # stream, which the rendering below relies on.
  module McpTransportConcern
    extend ActiveSupport::Concern

    private

    # allowed_hosts comes from config.hosts, not from a key of our own: the transport repeats a
    # check ActionDispatch::HostAuthorization already performs, which Rails installs whenever
    # config.hosts is non-empty -- and it is on every instance, because the shared
    # test/dummy/config/environments/production.rb pushes APP_HOST onto it. A second list would be
    # a second truth, and the one left empty answers every request with "403 Invalid Host header".
    #
    # grep(String): config.hosts also takes Regexp, IPAddr and Proc, the transport downcases each entry.
    #
    # serve_subscriptions_listen: false because these controllers buffer. Left on, a client that
    # speaks the 2026-07-28 modern lifecycle gets an SSE stream body back from subscriptions/listen,
    # and rendering it raises -- ActionController::API carries no ActionController::Live to hold the
    # response open. Off, the method falls through to the dispatcher and is answered as
    # "Method not found" (-32601), which is what this host can honestly say about it.
    def handle_mcp_request(server, mount)
      transport = MCP::Server::Transports::StreamableHTTPTransport.new(
        server,
        stateless: true,
        serve_subscriptions_listen: false,
        allowed_hosts: Rails.application.config.hosts.grep(String),
        allowed_origins: DataCycleCore::Feature::Mcp.allowed_origins(mount)
      )

      render_mcp_transport_response(transport)
    end

    # actionpack knows NO :headers option for render -- `render(json:, status:, headers:)` silently
    # discarded the transport headers. In stateless mode only content-type came back, so the loss
    # went unnoticed; switched to `stateless: false` the session id would be affected. Headers
    # belong on the response, not in the render options.
    #
    # An empty body means an empty body: the transport answers notifications/initialized with
    # [202, {}, []], and `render json: nil` turns that into the JSON literal `null`. head returns
    # the 202 without a body, as intended.
    def render_mcp_transport_response(transport)
      status, headers, body = transport.handle_request(request)

      headers&.each { |name, value| response.set_header(name, value) }

      # In stateless mode the Rack body is always an array (checked against mcp: POST, GET and
      # DELETE each return early there with [status, headers, [string]] or []). With
      # `stateless: false`, though, the same transport returns an SSE STREAM for POST and GET, and
      # as a Proc at that -- `body.first` would then be a NoMethodError in the middle of the
      # request, and the backtrace would not show the connection to the switched flag.
      #
      # A Proc body could not simply be passed through here either: that would need
      # ActionController::Live in the controller, which ActionController::API does not bring.
      # Hence an explicit error naming the cause, instead of silent wrong behaviour.
      raise "MCP transport returned a streaming body (#{body.class}); this concern renders buffered responses only -- SSE needs ActionController::Live (see stateless: in the controllers)" unless body.nil? || body.respond_to?(:first)

      payload = body&.first

      return head(status) if payload.blank?

      render(json: payload, status:)
    end
  end
end
