# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class SystemArea
        attr_reader :model_class, :properties

        def initialize(model_class, *properties)
          @model_class = model_class
          @properties = properties
        end
      end
    end
  end
end
