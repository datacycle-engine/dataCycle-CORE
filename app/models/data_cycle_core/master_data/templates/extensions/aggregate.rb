# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        module Aggregate
          AGGREGATE_PROPERTY_EXCEPTIONS = ['default_value', 'validations', 'compute'].freeze

          def add_inverse_aggregate_for_property!(data:)
            data[:data][:properties][:belongs_to_aggregate] = {
              label: 'mit Aggregat verknüpft',
              type: 'linked',
              inverse_of: 'aggregate_for',
              link_direction: 'inverse',
              template_name: aggregate_template_name(data:),
              api: {
                name: 'dc:belongsToAggregate'
              }
            }
          end

          def aggregate_template(data:, thing_template:)
            aggregate = data.deep_dup

            transform_aggregate_header!(aggregate:)
            transform_aggregate_features!(aggregate:)
            transform_aggregate_properties!(aggregate:, thing_template:)
            add_aggregate_property!(aggregate:, thing_template:)

            aggregate
          end

          def aggregate_template_name(data:)
            "#{data[:name]}Aggregate"
          end

          def aggregate_property_key(key:)
            "#{key}_aggregate"
          end

          private

          def transform_aggregate_header!(aggregate:)
            if aggregate[:data][:schema_ancestors].all?(::Array)
              aggregate[:data][:schema_ancestors].map! { |v| v.push("dcls:#{aggregate[:name]}") }
            else
              aggregate[:data][:schema_ancestors].push("dcls:#{aggregate[:name]}")
            end

            aggregate[:name] = aggregate_template_name(data: aggregate)
            aggregate[:data][:name] = aggregate[:name]
          end

          def transform_aggregate_features!(aggregate:)
            aggregate[:data][:features].delete(:overlay)
          end

          def transform_aggregate_properties!(aggregate:, thing_template:)
            aggregate[:data][:properties].except!(*thing_template.virtual_property_names)

            aggregate[:data][:properties].each do |key, prop|
              prop.except!(*AGGREGATE_PROPERTY_EXCEPTIONS)
              add_prop_ui_definition!(prop:)
              add_compute_definition_for_prop!(key:, prop:)
            end
          end

          def add_prop_ui_definition!(prop:)
            prop[:ui] ||= {}
            prop[:ui][:edit] ||= {}
            prop[:ui][:edit][:readonly] = true
          end

          def add_compute_definition_for_prop!(key:, prop:)
            prop[:compute] = {
              module: 'Common',
              method: 'attribute_value_from_first_linked',
              parameters: [
                "#{aggregate_property_key(key:)}.#{key}",
                "aggregate_for.#{key}"
              ]
            }
          end

          def add_aggregate_property!(aggregate:, thing_template:)
            props = {
              aggregate_for: {
                label: 'Aggregat für',
                type: 'linked',
                inverse_of: 'belongs_to_aggregate',
                template_name: thing_template.template_name,
                validations: {
                  required: true
                },
                api: {
                  name: 'dc:aggregateFor'
                }
              }
            }

            props.merge!(aggregate[:data][:properties])
            aggregate[:data][:properties] = props
          end
        end
      end
    end
  end
end
