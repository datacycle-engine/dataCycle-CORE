# frozen_string_literal: true

module DataCycleCore
  module ApiV4Helper
    def full_header_attributes
      ['@id', '@type', '@context', 'contentType', 'identifier', 'inLanguage', 'url']
    end

    def full_classification_header_attributes
      ['uri', '@type', 'identifier', 'prefLabel', 'description', 'inScheme', 'ancestors', 'broader', 'topConceptOf', 'created', 'updated', 'deleted']
    end

    def full_header_data(thing)
      full_header_attributes
        .zip([api_v4_thing_url(id: thing.id),
              thing.schema.dig('api', 'type') || thing.schema.dig('schema_type'),
              'http://schema.org',
              thing.template_name,
              thing.id,
              I18n.locale.to_s,
              thing_url(id: thing.id)])
        .to_h
    end

    def assert_compact_header(array)
      array.each do |hash|
        assert_equal(['@id', '@type'], hash.keys)
        assert(hash.dig('@id').present?)
        assert(hash.dig('@type').present?)
      end
    end

    def assert_compact_classification_header(array)
      array.each do |hash|
        assert_equal(['uri', '@type'], hash.keys)
        assert(hash.dig('uri').present?)
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
