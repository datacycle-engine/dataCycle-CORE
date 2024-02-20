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
      DataCycleCore::Thing.new(thing_template: self)
    end

    def schema_as_json
      content = schema_sorted
      embedded = template_thing.embedded_property_names

      embedded_template_names = content['properties'].values_at(*embedded).pluck('template_name')

      embedded_templates = DataCycleCore::ThingTemplate.where(template_name: embedded_template_names).index_by(&:template_name)

      embedded.each do |property_name|
        content['properties'][property_name]['embedded_schema'] = embedded_templates[content.dig('properties', property_name, 'template_name')].schema_as_json
      end

      content
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
  end
end
