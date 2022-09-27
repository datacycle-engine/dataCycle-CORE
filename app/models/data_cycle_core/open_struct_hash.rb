# frozen_string_literal: true

module DataCycleCore
  class OpenStructHash < OpenStruct
    def initialize(hash = nil)
      hash = hash.to_h { |k, v| [k, v.is_a?(::Hash) ? DataCycleCore::OpenStructHash.new(v) : v] } if hash

      super(hash)
    end

    def to_h
      if table.blank?
        as_hash = {}
      else
        as_hash = table.stringify_keys
        struct_keys = as_hash.select { |_, v| v.is_a? self.class }.map(&:first)
        struct_keys.each { |key| as_hash[key] = as_hash[key].to_h.compact }
      end
      as_hash.compact
    end

    def blank?
      to_h.values.all?(&:blank?)
    end
  end
end
