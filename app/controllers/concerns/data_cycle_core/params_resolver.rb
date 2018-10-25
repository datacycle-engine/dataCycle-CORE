# frozen_string_literal: true

module DataCycleCore
  module ParamsResolver
    extend ActiveSupport::Concern

    def resolve_params(params_hash = nil, resolve_instances = true)
      return {} if params_hash.blank?

      return_hash = {}
      params_hash = JSON.parse(params_hash) if params_hash.is_a?(String)
      params_hash = params_hash.to_unsafe_hash if params_hash.is_a?(ActionController::Parameters)

      return params_hash unless resolve_instances

      params_hash.presence&.each do |key, value|
        if value.is_a?(Hash) && value.key?('id') && value.key?('class')
          return_hash[key.to_sym] = value['class'].constantize.find_by(id: value['id']) if defined?(value['class'])
        elsif value.is_a?(Hash) && value.key?('ids') && value.key?('class')
          return_hash[key.to_sym] = value['class'].constantize.where(id: value['ids']) if defined?(value['class'])
        else
          return_hash[key.to_sym] = value
        end
      end

      return_hash
    end
  end
end
