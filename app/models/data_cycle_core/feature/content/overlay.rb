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

        def overlay_properties_for_base(property_name, include_overlay = false)
          overlay_base_name = name_property_selector(include_overlay) do |definition|
            definition.dig('features', 'overlay', 'overlay_for') == property_name &&
              definition.dig('features', 'overlay', 'overlay_type') == 'overlay'
          end

          return if overlay_base_name.blank?

          properties_for(overlay_base_name)
        end

        def api_name_for(property_path, definition = nil)
          definition = properties_for(property_path) if definition.blank?

          if definition&.dig('features', 'overlay', 'allowed')
            key = Array.wrap(property_path).last
            super(key, overlay_properties_for_base(key, true))
          elsif definition&.dig('features', 'overlay', 'overlay_for').present? &&
                definition.dig('features', 'overlay', 'overlay_type') != 'overlay'
            key = definition&.dig('features', 'overlay', 'overlay_for')
            super(key, overlay_properties_for_base(key, true))
          else
            super
          end
        end
      end
    end
  end
end
