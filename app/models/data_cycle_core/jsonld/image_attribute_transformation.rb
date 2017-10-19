module DataCycleCore
  module Jsonld
    module ImageAttributeTransformation

      def to_h
        underscore_keys(self.except('@context', '@type', 'visibility', 'keywords', 'contentLocation')
          .merge({'external_key' => self['url'], 'data_type' => nil, 'keywords' => self['keywords'].try(:join, ' ')})
        )
      end

      private

      def underscore_keys(data_hash)
        Hash[data_hash.to_a.map { |k, v| [k.to_s.underscore, v.kind_of?(Hash) ? underscore_keys(v) : v] }]
      end

    end
  end
end
