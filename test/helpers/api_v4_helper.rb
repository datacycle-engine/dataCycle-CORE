# frozen_string_literal: true

module DataCycleCore
  module ApiV4Helper
    def full_header_attributes
      ['@id', '@type', 'dc:entity_url']
    end

    def full_classification_header_attributes
      ['@id', '@type', 'dc:entity_url', 'skos:prefLabel', 'dct:description', 'skos:inScheme', 'skos:ancestors', 'skos:broader', 'skos:topConceptOf', 'dct:created', 'dct:updated', 'dct:deleted']
    end

    def full_header_data(thing, languages = 'de')
      full_header_attributes
        .zip([thing.id,
              thing.schema.dig('api', 'type') || thing.schema.dig('schema_type'),
              api_v4_thing_url(id: thing.id, language: languages)])
        .to_h
    end

    def assert_compact_header(array)
      array.each do |hash|
        assert_equal(['@id', '@type'], hash.keys)
        assert(hash.dig('@id').present?)
        assert(hash.dig('@type').present?)
      end
    end

    def assert_concept_attributes(concept)
      concept
        .keys
        .map { |key| full_classification_header_attributes.include?(key) }
        .inject(&:&)
    end
  end
end
