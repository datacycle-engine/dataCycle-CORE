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

              add_priority_for_single_geographic_property!(template[:data][:properties])
              check_priority_for_geographic_properties!(template[:data][:properties], error_path)
              check_priority_uniqueness!(template[:data][:properties], error_path)
            end
          end

          private

          def add_priority_for_single_geographic_property!(properties)
            geo_props = properties.select { |_, v| v&.dig(:type) == 'geographic' }
            return unless geo_props.one?
            return if geo_props.all? { |_, v| v.key?(:priority) }

            geo_props.values.first[:priority] = 1
          end

          def check_priority_for_geographic_properties!(properties, error_path)
            geo_wo_prio_props = properties.select { |_, v| v&.dig(:type) == 'geographic' && !v.key?(:priority) }

            return unless geo_wo_prio_props.any?

            geo_wo_prio_props.each_key do |key|
              @errors.push("#{error_path}.properties.#{key}.priority => is missing")
            end
          end

          def check_priority_uniqueness!(properties, error_path)
            geo_w_prio_props = properties
              .select { |_, v| v&.dig(:type) == 'geographic' && v.key?(:priority) }
              .group_by { |_, v| v[:priority] }

            return unless geo_w_prio_props.values.any?(&:many?)

            geo_w_prio_props.each do |priority, props|
              next if props.one?

              props.each do |(key, _)|
                @errors.push("#{error_path}.properties.#{key}.priority => is not unique: #{priority}")
              end
            end
          end
        end
      end
    end
  end
end
