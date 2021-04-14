# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.hashify_data(data, key)
          return data unless data.key?(key)
          data[key] = data[key].map { |i|
            if i.keys.size > 2
              { i['t'] => i.except('t') }
            else
              { i['t'] => i['v'] }
            end
          }.inject(&:merge)
          data
        end
      end
    end
  end
end
