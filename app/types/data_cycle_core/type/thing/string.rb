# frozen_string_literal: true

module DataCycleCore
  module Type
    module Thing
      class String < ActiveRecord::Type::String
        def cast(value)
          return super if value.blank?

          DataCycleCore::MasterData::DataConverter.string_to_string(value)

          super(Array.wrap(value).map { |filter| param_from_definition(filter) })
        end
      end
    end
  end
end
