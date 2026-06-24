# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        module Geographic
          def check_priorities_for_geographic_properties!
            @templates.each do |template|
              next if template.dig(:data, :properties).blank?

              error_path = "#{template[:set]}.#{template[:name]}"
              valid = true

              add_priority_for_single_geographic_property!(template[:data][:properties])
              valid &&= priorities_present?(template[:data][:properties], error_path)
              valid &&= priorities_unique?(template[:data][:properties], error_path)
              add_priority_for_overlay_properties!(template[:data][:properties]) if valid
            end
          end

          private

          def relevant_prop?(defition)
            defition&.dig(:type) == 'geographic' &&
              !defition.key?(:virtual)
          end

          def add_priority_for_single_geographic_property!(properties)
            geo_props = properties.select do |_, v|
              relevant_prop?(v) &&
                !v.dig(:features, :overlay, :overlay_for)
            end
            return unless geo_props.one?
            return if geo_props.all? { |_, v| v.key?(:priority) }

            geo_props.values.first[:priority] = 1
          end

          def add_priority_for_overlay_properties!(properties)
            geo_props = properties.select { |_, v| relevant_prop?(v) }

            return if geo_props.blank?
            return if geo_props.none? { |_, v| v.dig(:features, :overlay, :overlay_for) }

            geo_props.reject { |_, v| v.key?(:priority) }.each_value do |v|
              v[:priority] = geo_props[v.dig(:features, :overlay, :overlay_for)][:priority]
            end

            geo_props.sort_by { |_, v| [v[:priority], v.dig(:features, :overlay, :overlay_for)&.size || 99] }
              .each.with_index(1) do |(_, v), index|
              v[:priority] = index
            end
          end

          def priorities_present?(properties, error_path)
            geo_wo_prio_props = properties.select do |_, v|
              relevant_prop?(v) &&
                !v.key?(:priority) &&
                !v.dig(:features, :overlay, :overlay_for)
            end

            return true unless geo_wo_prio_props.any?

            geo_wo_prio_props.each_key do |key|
              @errors.push("#{error_path}.properties.#{key}.priority => is missing")
            end

            false
          end

          def priorities_unique?(properties, error_path)
            geo_w_prio_props = properties
              .select { |_, v| relevant_prop?(v) && v.key?(:priority) }
              .group_by { |_, v| v[:priority] }

            return true unless geo_w_prio_props.values.any?(&:many?)

            geo_w_prio_props.each do |priority, props|
              next if props.one?

              props.each do |(key, _)|
                @errors.push("#{error_path}.properties.#{key}.priority => is not unique: #{priority}")
              end
            end

            false
          end
        end
      end
    end
  end
end
