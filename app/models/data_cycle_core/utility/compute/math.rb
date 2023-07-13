# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Math
        class << self
          def sum(computed_parameters:, **_args)
            computed_parameters.values.flatten.grep(::Numeric).sum
          end

          def count_classifications_by_tree_label(computed_parameters:, computed_definition:, **_args)
            computed_parameters&.values&.flatten&.then { |v| DataCycleCore::Classification.where(id: v).for_tree(computed_definition.dig('compute', 'tree_label')) }&.count || 0
          end
        end
      end
    end
  end
end
