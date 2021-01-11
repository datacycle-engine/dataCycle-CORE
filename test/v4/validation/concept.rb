# frozen_string_literal: true

module DataCycleCore
  module V4
    module Validation
      class Concept
        DEFAULT_HEADER = Dry::Schema.JSON do
          required(:@id).value(:uuid_v4?)
          required(:@type).value(:string)
        end

        IDENTIFIER_ATTRIBUTES = Dry::Schema.JSON do
          required(:'@type').value(:string)
          required(:propertyID).value(:string)
          required(:value).value(:string)
        end

        DEFAULT_CONCEPT_SCHEME_ATTRIBUTES = Dry::Schema.JSON do
          optional(:'dc:multilingual').value(:bool)
          optional(:'dc:translation').array(:str?)
          required(:'dc:entityUrl').value(:string)
          required(:'skos:prefLabel').value(:string)
          required(:'dc:hasConcept').value(:string)
          required(:'dct:created').value(:date_time)
          required(:'dct:modified').value(:date_time)
          optional(:'dct:deleted').value(:date_time)
        end

        DEFAULT_CONCEPT_ATTRIBUTES = Dry::Schema.JSON do
          optional(:'dc:multilingual').value(:bool)
          optional(:'dc:translation').array(:str?)
          required(:'dc:entityUrl').value(:string)
          required(:'skos:prefLabel').value(:string)
          required(:'dct:created').value(:date_time)
          required(:'dct:modified').value(:date_time)
          optional(:'dct:deleted').value(:date_time)
          optional(:'dct:description').value(:string)
          optional(:url).value(:string)
          required(:'skos:inScheme').hash(DEFAULT_HEADER)
          optional(:'skos:topConceptOf').hash(DEFAULT_HEADER)
          optional(:'skos:broader').hash(DEFAULT_HEADER)
          optional(:'skos:ancestors').value(:array, min_size?: 1).each do
            hash(DEFAULT_HEADER)
          end
          optional(:identifier).value(:array, min_size?: 1).each do
            hash(IDENTIFIER_ATTRIBUTES)
          end
        end

        def self.build_concept_scheme_validation(fields, _include)
          return fields if fields.present?
          DEFAULT_CONCEPT_SCHEME_ATTRIBUTES
        end

        def self.build_concept_validation(fields, include)
          return fields if fields.present?
          return DEFAULT_CONCEPT_ATTRIBUTES.merge(include) if include.present?
          DEFAULT_CONCEPT_ATTRIBUTES
        end

        def self.concept_scheme(params: {})
          fields = params.dig(:fields)
          include = params.dig(:include)
          attributes = build_concept_scheme_validation(fields, include)
          validator = Dry::Validation.Contract do
            config.validate_keys = true
            json(DEFAULT_HEADER, attributes)
          end
          validator
        end

        def self.concept(params: {})
          fields = params.dig(:fields)
          include = params.dig(:include)
          attributes = build_concept_validation(fields, include)
          validator = Dry::Validation.Contract do
            config.validate_keys = true
            json(DEFAULT_HEADER, attributes)
          end
          validator
        end
      end
    end
  end
end
