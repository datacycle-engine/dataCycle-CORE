# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class DataAttributeAllowedForUpdate < DataAttribute
        def attribute_not_external?(attribute)
          return true if attribute.definition.dig('global').to_s == 'true'
          return true if attribute.content.try(:external_source_id).blank? && attribute.definition.dig('external').to_s != 'true'

          return true if DataCycleCore::Feature::Overlay.allowed?(attribute.content) && DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)

          false
        end

        def attribute_not_disabled?(attribute)
          attribute.definition.deep_stringify_keys.dig('ui', 'edit', 'disabled').to_s != 'true'
        end

        def attribute_not_read_only?(attribute)
          attribute.definition.deep_stringify_keys.dig('ui', 'edit', 'readonly').to_s != 'true'
        end
      end
    end
  end
end
