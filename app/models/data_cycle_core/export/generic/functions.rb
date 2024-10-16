# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module Functions
        extend FunctionsExtensions

        def self.filter(**)
          DataCycleCore::Export::Generic::Filter.filter(**)
        end
      end
    end
  end
end
