# frozen_string_literal: true

module DataCycleCore
  class ThingTemplate < ApplicationRecord
    has_many :things, inverse_of: :thing_template, foreign_key: :template_name, primary_key: :template_name

    scope :with_template_names, ->(template_names) { where(template_name: template_names) }
    scope :without_template_names, ->(template_names) { where.not(template_name: template_names) }
    scope :with_default_data_type, lambda { |classification_alias_names|
      template_types = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').where(internal_name: classification_alias_names).with_descendants.pluck(:internal_name)

      where("schema -> 'properties' -> 'data_type' ->> 'default_value' IN (?)", template_types)
    }

    def readonly?
      true
    end

    def property_definitions
      schema&.[]('properties') || {}
    end

    def schema_sorted
      sorted_properties = schema.dig('properties').map { |key, value| { key => value } }.sort_by { |i| i.values.first.dig('sorting') }.inject(&:merge)
      schema.deep_dup.merge({ 'properties' => sorted_properties })
    end

    def property_names
      property_definitions.keys
    end
    alias properties property_names

    def template_thing
      tt = DataCycleCore::Thing.new(thing_template: self)
      tt.readonly!
      tt
    end

    def all_templates
      return @all_templates if defined? @all_templates
      @all_templates = self.class.all.index_by(&:template_name)
      @all_templates.each_value { |v| v.instance_variable_set(:@all_templates, @all_templates) }
      @all_templates
    end

    def schema_as_json
      content = schema_sorted
      embedded = template_thing.embedded_property_names

      # embedded_template_names = content['properties'].values_at(*embedded).pluck('template_name').flatten

      # embedded_templates = DataCycleCore::ThingTemplate.where(template_name: embedded_template_names).index_by(&:template_name)

      embedded.each do |property_name|
        content['properties'][property_name]['embedded_schema'] = Array.wrap(content.dig('properties', property_name, 'template_name')).map { |et| all_templates[et].schema_as_json }
      end

      content
    end

    def self.schema_as_json
      all_templates = first.all_templates

      all.map do |tt|
        tt.instance_variable_set(:@all_templates, all_templates)
        tt.schema_as_json
      end
    end

    def schema_types
      schema_ancestors.map do |ancestors|
        ancestors.push("dcls:#{template_name}") if ancestors.last != template_name
        ancestors
      end
    end

    def schema_ancestors
      Array.wrap(schema&.[]('schema_ancestors')).deep_dup.then { |a| a.present? && !a.all?(::Array) ? [a] : a }
    end

    def self.template_things
      all.map(&:template_thing)
    end

    def self.translated_property_labels(locale:, attributes:, count: nil, specific: nil)
      return {} if attributes.blank?

      keys = attributes.is_a?(::Hash) ? attributes.keys : attributes

      DataCycleCore::ContentProperties.includes(:thing_template).where(property_name: keys).group_by(&:property_name)
      .to_h do |key, cps|
        [
          key,
          cps.map { |cp|
            next unless attributes.is_a?(::Array) || attributes[cp.property_name]&.include?(cp.template_name)

            DataCycleCore::Thing.human_attribute_name(cp.property_name, {
              base: cp.thing_template.template_thing,
              locale:,
              definition: cp.property_definition,
              locale_string: false,
              count:,
              specific:
            })
          }.compact.uniq.join(' / ')
        ]
      end
    end

    def self.translated_property_names(locale:)
      template_things
        .to_h do |t|
          [
            t.template_name,
            t.property_names.index_with do |k|
              definition = t.properties_for(k)
              {
                text: t.class.human_attribute_name(k, { base: t, locale:, definition:, locale_string: false }),
                type: definition.dig('type'),
                template: definition.dig('type') == 'embedded' ? definition.dig('template_name') : nil,
                embedded_template: t.embedded?
              }
            end
          ]
        end
    end
  end
end
