# frozen_string_literal: true

module DataCycleCore
  module NormalizeService
    INTERNAL_PROPERTIES = DataCycleCore.internal_data_attributes

    def normalize_data_hash(data_hash)
      data_hash.deep_reject { |k, v| v.blank? || INTERNAL_PROPERTIES.include?(k) }
    end

    def self.normalize_parameters(params)
      params = params.to_h if params.is_a?(ActionController::Parameters)

      return params unless params.is_a?(::Hash)

      params.each do |key, value|
        next unless value.is_a?(::Hash)

        # If any non-integer keys
        if value.keys.find { |k, _| k =~ /\D/ }
          normalize_parameters(value)
        else
          params[key] = value.values
          value.each_value { |h| normalize_parameters(h) }
        end
      end
    end

    def self.normalize_encoding(string)
      string.scrub('').force_encoding('UTF-8').delete("\u0000")
    end
  end
end
