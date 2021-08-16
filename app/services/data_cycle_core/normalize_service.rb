# frozen_string_literal: true

module DataCycleCore
  module NormalizeService
    INTERNAL_PROPERTIES = DataCycleCore.internal_data_attributes

    def normalize_data_hash(data_hash)
      data_hash.deep_reject { |k, v| v.blank? || INTERNAL_PROPERTIES.include?(k) }
    end

    def self.normalize_parameters(params)
      params = params.to_h if params.is_a?(ActionController::Parameters)

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

    # def deep_reject(hash, &blk)
    #   deep_reject!(hash.dup, &blk)
    # end

    # def deep_reject!(hash, &blk)
    #   hash.each do |k, v|
    #     deep_reject!(v, &blk) if v.is_a?(Hash)
    #     if v.is_a?(Array)
    #       v.each do |val|
    #         deep_reject!(val, &blk) if val.is_a?(Hash)
    #       end
    #     end
    #     hash.delete(k) if yield(k, v)
    #   end
    # end
  end
end
