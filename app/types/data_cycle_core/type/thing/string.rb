# frozen_string_literal: true

module DataCycleCore
  module Type
    module Thing
      class String < ActiveRecord::Type::String
        def cast(value)
          return super if value.blank?

          value = DataCycleCore::MasterData::DataConverter.string_to_string(value)

          super
        end
      end
    end
  end
end
