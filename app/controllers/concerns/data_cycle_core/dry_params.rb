# frozen_string_literal: true

module DataCycleCore
  module DryParams
    def params_for(schema)
      result = schema.call(params.to_unsafe_hash)
      raise ActionController::BadRequest unless result.success?
      result.to_h
    end

    private

    def parse_json_string(value)
      parsed_value = JSON.parse(value)

      return value if parsed_value.is_a?(::String) && parsed_value != value

      parsed_value
    rescue JSON::ParserError, TypeError
      value
    end

    def parse_params_hash(params_hash)
      if params_hash.is_a?(String)
        params_hash = parse_json_string(params_hash)
      elsif params_hash.is_a?(ActionController::Parameters)
        params_hash = params_hash.to_unsafe_h
      end

      params_hash || {}
    end
  end
end
