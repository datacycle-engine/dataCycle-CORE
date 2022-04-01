# frozen_string_literal: true

module DataCycleCore
  class FixParamEncodingMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      begin
        Rack::Utils.parse_nested_query(env['QUERY_STRING'].to_s)
      rescue Rack::Utils::InvalidParameterError
        env['QUERY_STRING'] = URI.encode_www_form(
          URI.decode_www_form(
            DataCycleCore::NormalizeService.normalize_encoding(env['QUERY_STRING'].to_s)
          )
        )
      end

      @app.call(env)
    end
  end
end
