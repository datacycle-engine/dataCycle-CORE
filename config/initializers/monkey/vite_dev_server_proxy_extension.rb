# frozen_string_literal: true

module DataCycleCore
  # rack-proxy >= 1.0 refuses backends derived from the Host header (SSRF guard),
  # which is how ViteRuby::DevServerProxy reaches the dev server -- without an
  # explicit backend every asset request 502s.
  module ViteDevServerProxyExtension
    private

    def forward_to_vite_dev_server(env)
      super

      env['rack.backend'] = URI(config.origin)
    end
  end
end

if ViteRuby.run_proxy?
  raise 'ViteRuby::DevServerProxy#forward_to_vite_dev_server is gone, check patch!' unless ViteRuby::DevServerProxy.private_method_defined?(:forward_to_vite_dev_server)

  ViteRuby::DevServerProxy.prepend(DataCycleCore::ViteDevServerProxyExtension)
end
