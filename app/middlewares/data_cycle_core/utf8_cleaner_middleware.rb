# frozen_string_literal: true

module DataCycleCore
  class Utf8CleanerMiddleware
    SANITIZABLE_CONTENT_TYPES = [
      'text/plain',
      'application/x-www-form-urlencoded',
      'application/json',
      'text/javascript'
    ].freeze

    URI_FIELDS = [
      'SCRIPT_NAME',
      'REQUEST_PATH',
      'REQUEST_URI',
      'PATH_INFO',
      'HTTP_REFERER',
      'ORIGINAL_FULLPATH',
      'ORIGINAL_SCRIPT_NAME',
      'SERVER_NAME'
    ].freeze

    URI_ENCODED_CONTENT_TYPES = [
      'application/x-www-form-urlencoded'
    ].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(sanitize_env(env))
    rescue EOFError
      [400, {}, ['Bad Request']]
    end

    private

    def sanitize_env(env)
      request = Rack::Request.new(env)

      sanitize_env_rack_input(env) if SANITIZABLE_CONTENT_TYPES.include?(request.media_type)
      sanitize_env_keys(env, request.media_type)
      env
    end

    def sanitize_env_keys(env, content_type)
      URI_FIELDS.each do |field|
        env[field] = sanitized_string(env[field]) if env[field]
      end

      env['QUERY_STRING'] = reencode_urlencoded_value(env['QUERY_STRING']) if URI_ENCODED_CONTENT_TYPES.include?(content_type)
    end

    def sanitize_env_rack_input(env)
      cleaned_value = sanitized_string(env['rack.input'].read)
      env['rack.input'] = StringIO.new(cleaned_value) if cleaned_value
      env['rack.input'].rewind
    end

    def reencode_urlencoded_value(value)
      URI.encode_www_form(
        URI.decode_www_form(
          sanitized_string(value)
        )
      )
    end

    def sanitized_string(value)
      value.is_a?(String) ? value.sanitize_utf8 : value
    end
  end
end
