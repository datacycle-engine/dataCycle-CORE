# frozen_string_literal: true

module DataCycleCore
  # UUIDs for objects that have no row of their own: virtual attributes, the @id of an embedded
  # object in the API, or the request scoped StoredFilter built for a forced api_linked user_filter.
  class UuidService
    class << self
      # Replaces the last node of the parent UUID with that node XOR-ed against a hash of the key,
      # so the same pair always yields the same UUID.
      #
      # @param id [String] UUID of the object the generated one belongs to
      # @param key [String] identifies the sub-object within its parent, e.g. an attribute name
      # @return [String] UUID sharing all but the last node with +id+
      def generate(id, key)
        [
          id.sub(/(.*)-(\w+)$/, '\1'),
          (id.sub(/(.*)-(\w+)$/, '\2').hex ^ Digest::MD5.hexdigest(key)[0..11].hex).to_s(16).rjust(12, '0')
        ].join('-')
      end
    end
  end
end
