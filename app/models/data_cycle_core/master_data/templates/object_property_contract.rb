# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class ObjectPropertyContract < TemplatePropertyContract
        attr_accessor :property_name

        ALLOWED_NESTED_TYPES = ['string', 'text', 'number', 'boolean', 'datetime', 'date', 'object'].freeze

        NESTED_TYPE_PARAMS = Dry::Schema.JSON do
          required(:type).value(:string, included_in?: ALLOWED_NESTED_TYPES)
        end

        json(BASE_PARAMS, NESTED_TYPE_PARAMS)
      end
    end
  end
end
