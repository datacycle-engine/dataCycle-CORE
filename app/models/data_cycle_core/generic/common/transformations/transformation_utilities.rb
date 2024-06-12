# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Transformations
        module TransformationUtilities
          def resolve_attribute_path(data, path)
            path = Array.wrap(path)

            path.reduce(data) do |partial_data, key|
              if partial_data.is_a?(Hash)
                partial_data[key]
              elsif partial_data.is_a?(Array)
                partial_data.flatten.pluck(key)
              end
            end
          end
        end
      end
    end
  end
end
