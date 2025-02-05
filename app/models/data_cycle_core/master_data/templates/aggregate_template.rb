# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class AggregateTemplate
        BASE_AGGREGATE_POSTFIX = '_aggregate_for_override'
        AGGREGATE_PROP_EXCEPTIONS = ['default_value', 'validations', 'compute', 'sorting', 'inverse_of'].freeze
        AGGREGATE_PROPERTY_NAME = 'aggregate_for'
        AGGREGATE_INVERSE_PROPERTY_NAME = 'belongs_to_aggregate'
        ADDITIONAL_BASE_TEMPLATES_KEY = 'additional_base_templates'
        AGGREGATE_KEY_EXCEPTIONS = ['overlay'].freeze # keys that should not be included in the aggregate definition
        PROPS_WITHOUT_AGGREGATE = [AGGREGATE_PROPERTY_NAME, AGGREGATE_INVERSE_PROPERTY_NAME, *AGGREGATE_KEY_EXCEPTIONS, 'id', 'external_key', 'schema_types', 'date_created', 'date_modified', 'date_deleted', 'data_type', 'slug'].freeze # keys that should not be aggregated
        ALLOWED_PROP_OVERRIDES = ['features', 'ui'].freeze
        AGGREGATE_TEMPLATE_SUFFIX = ' (Aggregate)'

        def initialize(data:)
          @data = data
          @aggregate = @data.dc_deep_dup.with_indifferent_access
        end

        def self.merge_belongs_to_aggregate_property!(data:, aggregate_name:)
          if data[:properties][AGGREGATE_INVERSE_PROPERTY_NAME.to_sym]
            data[:properties][AGGREGATE_INVERSE_PROPERTY_NAME.to_sym][:template_name] = (Array.wrap(data[:properties][AGGREGATE_INVERSE_PROPERTY_NAME.to_sym][:template_name]) + [aggregate_name]).uniq
          else
            data[:properties][AGGREGATE_INVERSE_PROPERTY_NAME.to_sym] = {
              type: 'linked',
              sorting: data[:properties].values.pluck('sorting').max + 1,
              inverse_of: AGGREGATE_PROPERTY_NAME,
              link_direction: 'inverse',
              template_name: aggregate_name,
              api: {
                name: 'dc:belongsToAggregate'
              }
            }
          end
        end

        def import
          transform_aggregate_header!
          transform_aggregate_features!
          transform_aggregate_properties!
          transform_override_properties!
          transform_inverse_properties!
          add_aggregate_property!

          @aggregate
        end

        def self.aggregate_template_name(name)
          "#{name}#{AGGREGATE_TEMPLATE_SUFFIX}"
        end

        def self.aggregate_property_key(key)
          "#{key}#{BASE_AGGREGATE_POSTFIX}"
        end

        def self.key_allowed_for_aggregate?(key:, prop:)
          PROPS_WITHOUT_AGGREGATE.exclude?(key) &&
            !prop.key?(:virtual) &&
            (!prop.key?(:compute) || prop.dig(:features, :aggregate, :allowed))
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
          @aggregate[:features][:aggregate] = { aggregate: true }
        end

        def transform_override_properties!
          return if @data.dig(:features, :aggregate, :features).blank?

          @aggregate[:features].deep_merge!(@data.dig(:features, :aggregate, :features))
        end

        def transform_aggregate_properties!
          props = []

          @aggregate[:properties].each do |key, prop|
            props.concat(transform_aggregate_property(key:, prop:))
          end

          @aggregate[:properties] = props.to_h
        end

        def transform_inverse_properties!
          @aggregate[:properties].each_value do |prop|
            next unless prop[:type] == 'linked' && prop[:link_direction] == 'inverse'
            prop.except!(:inverse_of, :link_direction)
          end
        end

        def slug_definition(key:, prop:)
          new_prop = prop.dc_deep_dup
          new_prop[:compute] = {
            module: 'Slug',
            method: 'slug_value_from_first_existing_linked',
            parameters: [
              "#{self.class.aggregate_property_key(key)}.#{key}",
              "#{AGGREGATE_PROPERTY_NAME}.#{key}"
            ]
          }

          [[key, new_prop]]
        end

        def transform_aggregate_property(key:, prop:)
          return [] if AGGREGATE_KEY_EXCEPTIONS.include?(key)
          return [] if prop.dig(:features, :overlay)&.key?(:overlay_for) || prop.dig(:features, :aggregate)&.key?(:aggregate_for)
          return slug_definition(key:, prop:) if key == 'slug'
          return [[key, prop]] unless self.class.key_allowed_for_aggregate?(key:, prop:)

          prop.except!(*AGGREGATE_PROP_EXCEPTIONS)
          add_prop_ui_definition!(prop:)
          add_compute_definition_for_prop!(key:, prop:)
          add_feature_definition_for_prop!(prop:)
          prop[:overlay] = true if TemplatePropertyContract::ALLOWED_OVERLAY_TYPES.include?(prop[:type]) && TemplatePropertyContract::OVERLAY_KEY_EXCEPTIONS.exclude?(key)

          transform_nested_properties!(prop:) if prop.key?(:properties)

          [
            [
              self.class.aggregate_property_key(key),
              aggregate_property_definition(key:, prop:)
            ],
            [key, prop]
          ]
        end

        def transform_nested_properties!(prop:)
          prop[:properties].each_value do |nested_prop|
            add_prop_ui_definition!(prop: nested_prop)
          end
        end

        def aggregate_property_definition(key:, prop:)
          # embedded should use plural for labels
          {
            label: { key:, key_prefix: 'aggregate_for_override', count: prop['type'] == 'embedded' ? 2 : nil },
            type: 'linked',
            template_name: aggregate_base_template_name,
            visible: ['show', 'edit'],
            features: { aggregate: { aggregate_for: key } },
            ui: {
              show: {
                disabled: prop.dig(:ui, :show, :disabled),
                attribute_group: prop.dig(:ui, :show, :attribute_group)
              },
              edit: {
                disabled: prop.dig(:ui, :edit, :disabled),
                options: {
                  limited_by: "thing[datahash][#{AGGREGATE_PROPERTY_NAME}]"
                },
                attribute_group: prop.dig(:ui, :show, :attribute_group)
              },
              attribute_group: prop.dig(:ui, :attribute_group)
            }
          }.deep_reject { |_, v| DataHashService.blank?(v) }
        end

        def aggregate_base_template_name
          if @data.dig('features', 'aggregate', ADDITIONAL_BASE_TEMPLATES_KEY).present?
            ([@data[:name]] + Array.wrap(@data.dig('features', 'aggregate', ADDITIONAL_BASE_TEMPLATES_KEY))).uniq
          else
            @data[:name]
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
            method: 'attribute_value_from_first_existing_linked',
            parameters: [
              "#{self.class.aggregate_property_key(key)}.#{key}",
              "#{AGGREGATE_PROPERTY_NAME}.#{key}"
            ]
          }
        end

        def add_feature_definition_for_prop!(prop:)
          override_props = prop.dig('features', 'aggregate')&.slice(*ALLOWED_PROP_OVERRIDES) || {}
          prop[:features] = {
            aggregate: { allowed: true }
          }
          prop.deep_merge!(override_props)
        end

        def add_aggregate_property!
          props = {
            AGGREGATE_PROPERTY_NAME.to_sym => {
              type: 'linked',
              inverse_of: AGGREGATE_INVERSE_PROPERTY_NAME,
              template_name: aggregate_base_template_name,
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
