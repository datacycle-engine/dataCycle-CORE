# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Classification
        class << self
          def by_name(**args)
            Array.wrap(DataCycleCore::ClassificationAlias.classification_for_tree_with_name(args.dig(:property_definition, 'tree_label'), args.dig(:property_definition, 'default_value')))
          end
        end
      end
    end
  end
end
