# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        module Position
          # Adds sorting to the properties of a template
          # repositions properties based on the position attribute and initial order
          def sort_properties!(properties)
            sortable_props = properties.filter { |_k, prop| prop&.key?(:position) }

            return properties if sortable_props.blank?

            ordered_props = properties.to_a
            key_proc = ->(k2, p2) { (p2.dig('features', 'overlay', 'overlay_for') || k2) }

            sortable_props.each do |k, prop|
              position = prop.delete(:position)
              ordered_props.reject! { |(k1, _)| k1 == k }
              ordered_keys = ordered_props.pluck(0)

              @errors.push("#{@error_path}.properties.#{k} => position must be either 'before' or 'after', not both!") && next if position.key?(:after) && position.key?(:before)

              if position.key?(:after)
                @errors.push("#{@error_path}.properties.#{k} => attribute '#{position[:after]}' missing for position: { after: #{position[:after]} }") && next if ordered_keys.exclude?(position[:after])

                if prop.dig('features', 'overlay', 'allowed')
                  new_index = ordered_keys.index(position[:after]) + 1
                else
                  new_index = ordered_props.rindex { |(k1, p1)| key_proc.call(k1, p1) == position[:after] } + 1
                end
              else
                @errors.push("#{@error_path}.properties.#{k} => attribute '#{position[:before]}' missing for position: { before: #{position[:before]} }") && next if ordered_keys.exclude?(position[:before])

                new_index = ordered_keys.index(position[:before])
              end

              ordered_props.insert(new_index, [k, prop])
            end

            properties.slice!(*ordered_props.pluck(0))
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
