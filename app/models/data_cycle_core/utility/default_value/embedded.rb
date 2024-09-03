# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Embedded
        class << self
          def gip_start_end_waypoints(**_additional_args)
            [{ name: 'Start' }, { name: 'Ende' }]
          end

          def by_name_value_source(content:, property_definition:, **_args)
            value_definition = property_definition.dig('default_value', 'value')
            if value_definition.is_a?(::Array)
              values = value_definition
            else
              values = (content&.external? ? value_definition.dig('external') : value_definition.dig('internal')) || []
            end

            first_template = Array.wrap(property_definition.dig('template_name')).first

            values.map do |value|
              value['template_name'] ||= first_template
              value
            end
          end
        end
      end
    end
  end
end
