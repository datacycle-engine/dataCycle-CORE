# frozen_string_literal: true

require 'dry/transformer'

module DataCycleCore
  module Generic
    module DataCycleApiV4
      module Functions
        extend Dry::Transformer::Registry

        import Dry::Transformer::Coercions
        import Dry::Transformer::ArrayTransformations
        import Dry::Transformer::HashTransformations
        import Dry::Transformer::ClassTransformations
        import Dry::Transformer::ProcTransformations
        import Dry::Transformer::Conditional
        import Dry::Transformer::Recursion

        def self.strip_all(data_hash)
          data_hash.to_a.to_h do |k, v|
            [k, if v.is_a?(Hash)
                  strip_all(v)
                else
                  (v.is_a?(String) ? v.strip : v)
                end]
          end
        end

        def self.underscore_keys(data_hash)
          data_hash.to_a.to_h { |k, v| [k.to_s.underscore, v.is_a?(Hash) ? underscore_keys(v) : v] }
        end
      end
    end
  end
end
