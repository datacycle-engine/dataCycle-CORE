# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      class Base
        include FunctionsExtensions

        attr_accessor :action

        def initialize(action:)
          @action = action.to_sym
        end

        def process(utility_object:, data:)
          return if data.blank?

          uo = utility_object.dup.tap { |u| u.endpoint_method = action.to_sym }

          enqueue(utility_object: uo, data:)
        end

        def filter(data, external_system)
          Filter.filter(data:, external_system:, method_name: action.to_s)
        end
      end
    end
  end
end
