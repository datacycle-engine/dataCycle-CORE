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

    def property_names
      property_definitions.keys
    end
    alias properties property_names

    def template_thing
      DataCycleCore::Thing.new(thing_template: self)
    end

    def self.template_things
      all.map(&:template_thing)
    end
  end
end
