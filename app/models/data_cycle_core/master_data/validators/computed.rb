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
            'classification' => Validators::Classification
          }
        end

        def validate(data, template, _strict = false)
          validator_object = computed_types[template.dig('compute', 'type')].new(data, template)
          merge_errors(validator_object.error) unless validator_object.nil?
        end
      end
    end
  end
end
