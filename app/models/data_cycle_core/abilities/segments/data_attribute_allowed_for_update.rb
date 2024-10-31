# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class DataAttributeAllowedForUpdate < DataAttribute
        def attribute_not_external?(attribute)
          return true if attribute.definition['global'].to_s == 'true' || attribute.definition['local'].to_s == 'true'
          return true if attribute.content.try(:external_source_id).blank? && attribute.definition['external'].to_s != 'true'

          return true if DataCycleCore::Feature::Overlay.allowed?(attribute.content) && DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)

          false
        end
      end
    end
  end
end
