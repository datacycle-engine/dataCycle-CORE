# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelIdentityServer
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.reject_all_keys(data, except: [])
          data.select { |k, _| except.blank? || except.include?(k) }
        end

        def self.flatten_hash_keys(data, key)
          data.tap { |m| m[key] = m[key]&.values&.flatten&.uniq }
        end
      end
    end
  end
end
