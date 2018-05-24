# frozen_string_literal: true

module DataCycleCore
  module NormalizeService
    INTERNAL_PROPERTIES = DataCycleCore.internal_data_attributes

    def normalize_data_hash(data_hash)
      deep_reject(data_hash) { |k, v| v.blank? || INTERNAL_PROPERTIES.include?(k) }
    end

    def deep_reject(hash, &blk)
      deep_reject!(hash.dup, &blk)
    end

    def deep_reject!(hash, &blk)
      hash.each do |k, v|
        deep_reject!(v, &blk) if v.is_a?(Hash)
        if v.is_a?(Array)
          v.each do |val|
            deep_reject!(val, &blk) if val.is_a?(Hash)
          end
        end
        hash.delete(k) if yield(k, v)
      end
    end
  end
end
