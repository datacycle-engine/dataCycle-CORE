# frozen_string_literal: true

module DataCycleCore
  module Export
    module Common
      module Endpoint
        class GenericEndpoint
          def initialize(**options)
            @host = options.dig(:host)

            # TODO: add Default Logging
          end

          def connection
            raise 'Missing host to create connection' if @host.blank?

            Faraday.new(@host) do |connection|
              connection.use FaradayMiddleware::FollowRedirects, limit: 5
              connection.adapter Faraday.default_adapter
            end
          end
        end
      end
    end
  end
end
