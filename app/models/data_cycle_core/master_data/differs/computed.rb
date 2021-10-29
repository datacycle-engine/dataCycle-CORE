# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Computed < Basic
        def computed_types
          {
            'object' => Differs::Object,
            'string' => Differs::String,
            'number' => Differs::Number,
            'datetime' => Differs::Datetime,
            'boolean' => Differs::Boolean,
            'geographic' => Differs::Geographic,
            'asset' => Differs::Asset,
            'classification' => Differs::Classification
          }
        end

        def diff(a, b, template, _partial_update)
          @diff_hash = computed_types[template.dig('compute', 'type')].new(a, b, template).diff_hash
        end
      end
    end
  end
end
