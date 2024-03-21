# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        module Position
          def sort_properties!(properties)
            sortable_props = properties.filter { |_k, prop| prop&.key?(:position) }

            return properties if sortable_props.blank?

            ordered_keys = properties.keys

            sortable_props.each do |k, prop|
              position = prop.delete(:position)
              ordered_keys.delete(k)

              if position.key?(:after)
                raise TemplateError.new("properties.#{k}"), "attribute '#{position[:after]}' missing for position: { after: #{position[:after]} }" if ordered_keys.exclude?(position[:after])

                if Overlay.overlay_attribute?(k)
                  new_index = ordered_keys.index(position[:after]) + 1
                else
                  new_index = ordered_keys.rindex { |v| Overlay.key_without_overlay_type(v) == position[:after] } + 1
                end
              else
                raise TemplateError.new("properties.#{k}"), "attribute '#{position[:before]}' missing for position: { before: #{position[:before]} }" if ordered_keys.exclude?(position[:before])

                new_index = ordered_keys.index(position[:before])
              end

              ordered_keys.insert(new_index, k)
            end

            properties.slice!(*ordered_keys)
            properties
          end

          def add_sorting_recursive!(properties)
            return properties if properties.blank?

            sort_properties!(properties)

            properties.deep_reject! { |_, v| v.nil? }

            properties.each_value.with_index(1) do |value, index|
              value[:sorting] = index

              add_sorting_recursive!(value[:properties]) if value[:type] == 'object' && value.key?(:properties)
            end

            properties
          end
        end
      end
    end
  end
end
