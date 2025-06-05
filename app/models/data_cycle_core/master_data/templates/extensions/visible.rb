# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        module Visible
          VISIBILITIES = {
            'api' => { 'api' => { 'disabled' => true } },
            'xml' => { 'xml' => { 'disabled' => true } },
            'show' => { 'ui' => { 'show' => { 'disabled' => true } } },
            'edit' => { 'ui' => { 'edit' => { 'disabled' => true } } }
          }.freeze

          def transform_visibilities!
            @templates.each do |template|
              next if template.dig(:data, :properties).blank?

              transform_visibilities_recursive!(template[:data][:properties])
            end
          end

          def transform_visibilities_recursive!(properties)
            return properties if properties.blank?

            properties.transform_values! do |value|
              v = transform_visibility!(value)
              v[:properties] = transform_visibilities_recursive!(v[:properties]) if v[:type] == 'object' && v.key?(:properties)
              v
            end

            properties
          end

          def transform_visibility!(prop)
            return prop unless prop&.key?(:visible)

            visibility = prop.delete(:visible)

            return prop if visibility == true

            visibilities = visibility == false ? VISIBILITIES : VISIBILITIES.except(*Array.wrap(visibility))

            return prop if visibilities.blank?

            visibilities.values.reduce(&:deep_merge).deep_merge(prop).with_indifferent_access
          end

          def self.merge_visibility(visible, new_visible)
            case visible
            when Array then visible.intersection(new_visible)
            when FalseClass then false
            else new_visible
            end
          end
        end
      end
    end
  end
end
