module DataCycleCore
  module NormalizeService
    require 'hashdiff'

    INTERNAL_PROPERTIES = ['creator', 'data_pool', 'data_type', 'is_part_of']

    def data_hash_is_dirty?(data_hash, orig_data_hash)
      return !HashDiff.diff(normalize_data_hash(data_hash), normalize_data_hash(orig_data_hash), :array_path => true).blank?
    end

    def normalize_data_hash(data_hash)
      deep_reject(data_hash) { |k,v| v.blank? || INTERNAL_PROPERTIES.include?(k) }
    end

    def deep_reject(hash, &blk)
      deep_reject!(hash.dup, &blk)
    end

    def deep_reject!(hash, &blk)
      hash.each do |k, v|
        deep_reject!(v,&blk) if v.is_a?(Hash)
        if v.is_a?(Array)
          v.each do |val|
            deep_reject!(val, &blk) if val.is_a?(Hash)
          end
        end
        hash.delete(k) if blk.call(k, v)
      end
    end

  end
end
