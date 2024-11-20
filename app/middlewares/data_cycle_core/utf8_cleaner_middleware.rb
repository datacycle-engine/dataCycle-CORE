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

    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(sanitize_env(env))
    rescue EOFError, Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      [400, {}, ['Bad Request']]
    end

    private

    def sanitize_env(env)
      request = Rack::Request.new(env)

      sanitize_env_rack_input(env) if SANITIZABLE_CONTENT_TYPES.include?(request.media_type)
      sanitize_env_keys(env)
      env
    end

    def sanitize_env_keys(env)
      URI_FIELDS.each do |field|
        env[field] = sanitized_string(env[field]) if env[field]
      end

      env['QUERY_STRING'] = reencode_urlencoded_value(env['QUERY_STRING']) if env['QUERY_STRING'].present?
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
