# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class Computed < BasicValidator
        def computed_types
          {
            'object' => Validators::Object,
            'string' => Validators::String,
            'number' => Validators::Number,
            'datetime' => Validators::Datetime,
            'boolean' => Validators::Boolean,
            'geographic' => Validators::Geographic,
            'asset' => Validators::Asset,
            'classification' => Validators::Classification,
          }
        end

        def validate(data, template)
          computed_types[template.dig('compute', 'type')].new(data, template)
        end
      end
    end
  end
end
