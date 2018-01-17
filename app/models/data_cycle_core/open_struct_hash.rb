module DataCycleCore
  class OpenStructHash < OpenStruct
    def to_h
      if self.table.blank?
        as_hash = {}
      else
        as_hash = self.table.stringify_keys
        struct_keys = as_hash.select { |_, v| v.is_a? self.class }.map(&:first)
        struct_keys.each { |key| as_hash[key] = as_hash[key].to_h.compact }
      end
      as_hash.compact
    end
  end
end
