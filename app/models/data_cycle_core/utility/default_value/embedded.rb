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

            return value_definition if value_definition.is_a?(::Array)

            content&.external? ? value_definition.dig('external') : value_definition.dig('internal')
          end
        end
      end
    end
  end
end
