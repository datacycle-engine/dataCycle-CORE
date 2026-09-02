# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      # Virtual attributes delivering a number instead of a string.
      module Number
        class << self
          # Numeric part of the classification selected for the given tree_label,
          # read from the same key as String.classification_value (e.g. external_key
          # "columns-2" => 2). Used to expose count-like single-select classifications
          # as a number in the API.
          # :virtual:
          #   :module: Number
          #   :method: classification_value
          #   :tree_label: ColumnCounts
          #   :key: external_key
          def classification_value(**args)
            DataCycleCore::Utility::Virtual::String.classification_value(**args).to_s[/\d+/]&.to_i
          end
        end
      end
    end
  end
end
