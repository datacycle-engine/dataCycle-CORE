# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module Overlay
        def relevant_property_names(key)
          attribute_name = key&.attribute_name_from_key

          return [] if attribute_name.blank? || !property?(attribute_name)

          definition = properties_for(attribute_name)
          return super if definition.dig('features', 'overlay', 'overlay_for').blank?

          [definition.dig('features', 'overlay', 'overlay_for'), attribute_name]
        end
      end
    end
  end
end
