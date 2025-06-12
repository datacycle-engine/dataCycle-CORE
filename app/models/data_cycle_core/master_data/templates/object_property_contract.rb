# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class ObjectPropertyContract < TemplatePropertyContract
        attr_accessor :property_name

        ALLOWED_NESTED_TYPES = ['string', 'text', 'number', 'boolean', 'datetime', 'date', 'object'].freeze

        NESTED_TYPE_PARAMS = Dry::Schema.Params do
          required(:type) do
            str? & included_in?(ALLOWED_NESTED_TYPES)
          end
        end

        schema(BASE_PARAMS, NESTED_TYPE_PARAMS)
      end
    end
  end
end
