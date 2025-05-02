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
              values = (content&.external? ? value_definition['external'] : value_definition['internal']) || []
            end
            template_name = Array.wrap(property_definition['template_name'])
            first_template = template_name.first
            templates = DataCycleCore::ThingTemplate.where(
              template_name: template_name
            ).index_by(&:template_name)

            values.map do |value|
              value['template_name'] ||= first_template

              template = templates[value['template_name']].template_thing
              value.each do |k,v|
                if template.classification_property_names.include?(k)
                  tree_label = template.properties_for(k)&.dig('tree_label')
                  value[k] = DataCycleCore::Concept.for_tree(tree_label).where(internal_name: v).pluck(:classification_id)
                end
              end
              value
            end
          end
        end
      end
    end
  end
end
