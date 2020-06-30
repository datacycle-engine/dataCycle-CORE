# frozen_string_literal: true

require 'dry/transformer/all'

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
          Hash[data_hash.to_a.map { |k, v| [k, v.is_a?(Hash) ? strip_all(v) : (v.is_a?(String) ? v.strip : v)] }]
        end

        def self.underscore_keys(data_hash)
          Hash[data_hash.to_a.map { |k, v| [k.to_s.underscore, v.is_a?(Hash) ? underscore_keys(v) : v] }]
        end
      end
    end
  end
end
