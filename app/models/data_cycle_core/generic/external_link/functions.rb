# frozen_string_literal: true

require 'dry/transformer'

module DataCycleCore
  module Generic
    module ExternalLink
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
          data_hash.to_a.to_h { |k, v| [k, v.is_a?(Hash) ? strip_all(v) : (v.is_a?(String) ? v.strip : v)] }
        end

        def self.deep_stringify_keys(data_hash)
          data_hash.deep_stringify_keys
        end

        def self.add_field(data_hash, name, function)
          data_hash.merge({ name => function.call(data_hash) })
        end
      end
    end
  end
end
