# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class AggregateTemplate
        AGGREGATE_PROP_EXCEPTIONS = ['default_value', 'validations', 'compute'].freeze
        AGGREGATE_PROPERTY_NAME = 'aggregate_for'
        AGGREGATE_INVERSE_PROPERTY_NAME = 'belongs_to_aggregate'
        AGGREGATE_KEY_EXCEPTIONS = ['overlay'].freeze
        PROPS_WITHOUT_AGGREGATE = [AGGREGATE_PROPERTY_NAME, AGGREGATE_INVERSE_PROPERTY_NAME, *AGGREGATE_KEY_EXCEPTIONS, 'id'].freeze

        def initialize(data:, template_thing:)
          @data = data
          @aggregate = @data.deep_dup
          @template_thing = template_thing
        end

        def add_inverse_aggregate_for_property!(data:)
          data[:properties][AGGREGATE_INVERSE_PROPERTY_NAME.to_sym] = {
            label: 'mit Aggregat verknüpft',
            type: 'linked',
            sorting: data[:properties].values.pluck('sorting').max + 1,
            inverse_of: AGGREGATE_PROPERTY_NAME,
            link_direction: 'inverse',
            template_name: self.class.aggregate_template_name(data[:name]),
            api: {
              name: 'dc:belongsToAggregate'
            }
          }
        end

        def import
          transform_aggregate_header!
          transform_aggregate_features!
          transform_aggregate_properties!
          add_aggregate_property!

          @aggregate
        end

        def self.aggregate_template_name(name)
          "#{name} (Aggregate)"
        end

        def self.aggregate_property_key(key)
          "#{key}_aggregate_for_override"
        end

        def self.key_allowed_for_aggregate?(key:, template_thing:)
          (PROPS_WITHOUT_AGGREGATE + template_thing.virtual_property_names + template_thing.computed_property_names).exclude?(key)
        end

        private

        def transform_aggregate_header!
          if @aggregate[:schema_ancestors].all?(::Array)
            @aggregate[:schema_ancestors].map! { |v| v.push("dcls:#{@aggregate[:name]}") }
          else
            @aggregate[:schema_ancestors].push("dcls:#{@aggregate[:name]}")
          end

          @aggregate[:name] = self.class.aggregate_template_name(@aggregate[:name])
        end

        def transform_aggregate_features!
          @aggregate[:features] ||= {}
          @aggregate[:features][:overlay] = { allowed: true }
        end

        def transform_aggregate_properties!
          props = []

          @aggregate[:properties].each do |key, prop|
            next if AGGREGATE_KEY_EXCEPTIONS.include?(key)
            next props.push([key, prop]) unless self.class.key_allowed_for_aggregate?(key:, template_thing: @template_thing)

            prop.except!(*AGGREGATE_PROP_EXCEPTIONS)
            add_prop_ui_definition!(prop:)
            add_compute_definition_for_prop!(key:, prop:)
            prop[:overlay] = true if TemplatePropertyContract::ALLOWED_OVERLAY_TYPES.include?(prop[:type]) && TemplatePropertyContract::OVERLAY_KEY_EXCEPTIONS.exclude?(key)

            props.push([
                         self.class.aggregate_property_key(key),
                         aggregate_property_definition(prop:)
                       ])
            props.push([key, prop])
          end

          @aggregate[:properties] = props.to_h
        end

        def aggregate_property_definition(prop:)
          {
            label: "Aggregat-Override für #{prop[:label]}",
            type: 'linked',
            template_name: @template_thing.template_name,
            visible: ['show', 'edit'],
            ui: {
              edit: {
                options: {
                  limited_by: "thing[datahash][#{AGGREGATE_PROPERTY_NAME}]"
                }
              }
            }
          }
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
              "#{self.class.aggregate_property_key(key)}.#{key}",
              "#{AGGREGATE_PROPERTY_NAME}.#{key}"
            ]
          }
        end

        def add_aggregate_property!
          props = {
            AGGREGATE_PROPERTY_NAME.to_sym => {
              label: 'Aggregat für',
              type: 'linked',
              inverse_of: AGGREGATE_INVERSE_PROPERTY_NAME,
              template_name: @template_thing.template_name,
              validations: {
                required: true
              },
              api: {
                name: 'dc:aggregateFor'
              }
            }
          }

          props.merge!(@aggregate[:properties])
          @aggregate[:properties] = props
        end
      end
    end
  end
end
