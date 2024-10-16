# frozen_string_literal: true

module DataCycleCore
  module Export
    module Common
      module Endpoint
        class GenericEndpoint
          def initialize(**options)
            @host = options.dig(:host)
          end

          def connection
            raise 'Missing host to create connection' if @host.blank?

            Faraday.default_connection.dup.tap do |connection|
              connection.url_prefix = @host
            end
          end
        end
      end
    end
  end
end
