# frozen_string_literal: true

module DataCycleCore
  module ContentHelper
    def generate_uuid(id, key)
      [
        id.sub(/(.*)-(\w+)$/, '\1'),
        (id.sub(/(.*)-(\w+)$/, '\2').hex ^ Digest::MD5.hexdigest(key)[0..11].hex).to_s(16).rjust(12, '0')
      ].join('-')
    end
  end
end
