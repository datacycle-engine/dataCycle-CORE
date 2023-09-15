# frozen_string_literal: true

module DataCycleCore
  module ParamsResolver
    extend ActiveSupport::Concern

    def resolve_params(params_hash = nil, resolve_instances = true, symbolize_keys = true)
      return {} if params_hash.blank?

      return_hash = {}

      parse_params_hash(params_hash).each do |key, value|
        key = key.to_sym if symbolize_keys
        value = parse_json_string(value) if value.is_a?(String)

        if resolve_instances && value.is_a?(::Hash) && value.key?('id') && value.key?('class')
          next unless defined?(value['class'])

          class_name = value['class'].safe_constantize
          return_hash[key] = class_name.find_by(class_name.primary_key => value['id'])
        elsif resolve_instances && value.is_a?(::Hash) && value.key?('attributes') && value.key?('class')
          return_hash[key] = value['class'].safe_constantize.new(value['attributes']) if defined?(value['class'])
        elsif resolve_instances && value.is_a?(::Hash) && value.key?('ids') && value.key?('class')
          if defined?(value['class'])
            return_hash[key] = value['class']
              .safe_constantize
              .where(id: value['ids'])
              .order(
                [
                  Arel.sql("array_position(ARRAY[?]::uuid[], #{value['class'].safe_constantize.table_name}.id)"),
                  value['ids']
                ]
              )
          end
        elsif value.is_a?(::Hash) && value.key?('value') && value.key?('class')
          return_hash[key] = value['class'].safe_constantize.new(value['value'])
        elsif value.is_a?(::Hash) && value.key?('class') && value.except('class').blank?
          return_hash[key] = nil
        elsif value.is_a?(::Hash)
          return_hash[key] = resolve_params(value, resolve_instances, false).with_indifferent_access
        else
          return_hash[key] = value
        end
      end

      return_hash
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
