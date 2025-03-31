# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class DataAttributeAllowedForUpdate < DataAttribute
        def attribute_not_external?(attribute)
          return true if attribute.definition['global'].to_s == 'true' || attribute.definition['local'].to_s == 'true'
          return true if attribute.content.try(:external_source_id).blank? && attribute.definition['external'].to_s != 'true'

          return true if attribute_is_in_overlay?(attribute) || overlay_attribute?(attribute)

          false
        end
      end
    end
  end
end
