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

        if resolve_instances && value.is_a?(::Hash) && value.key?('class') && !(class_name = value['class'].classify.safe_constantize).nil?
          if value.key?(class_name.try(:primary_key)) && value[:type] == 'Collection'
            return_hash[key] = class_name.by_ordered_values(value[class_name.primary_key])
          elsif value.key?(class_name.try(:primary_key))
            return_hash[key] = class_name.find_by(class_name.primary_key => value[class_name.primary_key])
          elsif value.key?('attributes')
            return_hash[key] = class_name.new(resolve_params(value['attributes'], resolve_instances, false).with_indifferent_access)
          elsif value.except('class').present?
            return_hash[key] = value
          end
        elsif value.is_a?(::Hash) && value.key?('value') && value.key?('class')
          return_hash[key] = value['class'].classify.safe_constantize.new(value['value'])
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
