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

          def transform_visibilities!(properties)
            return properties if properties.blank?

            properties.transform_values! do |value|
              next value unless value&.key?(:visible)

              visibility = value.delete(:visible)

              next value if visibility == true

              visibilities = visibility == false ? VISIBILITIES : VISIBILITIES.except(*Array.wrap(visibility))

              visibilities.values.reduce(&:deep_merge).deep_merge(value).with_indifferent_access
            end

            properties
          end
        end
      end
    end
  end
end
