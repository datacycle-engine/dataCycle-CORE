# frozen_string_literal: true

module DataCycleCore
  module ApiV4Helper
    def full_header_attributes
      ['@id', '@type', 'name']
    end

    def full_classification_header_attributes
      ['@id', '@type', 'dc:entityUrl', 'dc:order', 'skos:prefLabel', 'dct:description', 'skos:inScheme', 'skos:ancestors', 'skos:broader', 'skos:topConceptOf', 'dct:created', 'dct:updated', 'dct:deleted']
    end

    def full_header_data(thing, languages = 'de')
      full_header_attributes
        .zip([thing.id,
              thing.api_type,
              header_name(thing, languages)]).to_h
    end

    def header_name(thing, languages = 'de')
      language_arr = languages.split(',')
      return (thing.title || thing.template_name) if language_arr.size == 1
      language_arr.map! do |lang|
        I18n.with_locale(lang) do
          { '@language' => I18n.locale.to_s, '@value' => (thing.title || thing.template_name) }
        end
      end
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
