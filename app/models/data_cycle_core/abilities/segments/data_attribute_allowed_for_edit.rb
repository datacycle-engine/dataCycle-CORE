# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class DataAttributeAllowedForEdit < DataAttribute
        def include?(attribute)
          return true if attribute.options[:force_render].to_s == 'true' && attribute_not_disabled?(attribute)

          super
        end
      end
    end
  end
end
