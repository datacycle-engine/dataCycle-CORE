# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Schemas
      module SharedComponents
        # skos:Concept / skos:ConceptScheme building blocks. Extended into
        # SharedComponents so its methods are available as
        # SharedComponents.* module methods (mirrors Localizable).
        module Classification
          # skos:Concept as delivered by _classification.jb.
          def concept
            {
              'type' => 'object',
              'title' => 'Concept',
              'description' => t('schemas.concept'),
              'properties' => {
                '@id' => id_property,
                '@type' => { 'type' => 'string', 'const' => 'skos:Concept' },
                'dc:multilingual' => { 'type' => 'boolean' },
                'dc:translation' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
                'dc:entityUrl' => { 'type' => 'string', 'format' => 'uri' },
                'skos:prefLabel' => translatable_value,
                'dct:description' => translatable_value,
                'url' => { 'type' => 'string', 'format' => 'uri' },
                'skos:inScheme' => { '$ref' => '#/components/schemas/ConceptScheme' },
                'skos:topConceptOf' => { '$ref' => '#/components/schemas/ConceptScheme' },
                'skos:broader' => { '$ref' => '#/components/schemas/Concept' },
                'skos:ancestors' => {
                  'type' => 'array',
                  'items' => { '$ref' => '#/components/schemas/Concept' }
                },
                'dct:created' => { 'type' => 'string', 'format' => 'date-time' },
                'dct:modified' => { 'type' => 'string', 'format' => 'date-time' },
                'dct:deleted' => { 'type' => ['string', 'null'], 'format' => 'date-time' },
                'dc:color' => { 'type' => 'string' },
                'dc:icon' => { 'type' => 'string' },
                'dc:slugifiedName' => translatable_value,
                'identifier' => {
                  'type' => 'array',
                  'items' => { '$ref' => '#/components/schemas/PropertyValue' }
                },
                'geo' => { '$ref' => '#/components/schemas/GeoShape' }
              },
              'required' => ['@id', '@type']
            }
          end

          # skos:ConceptScheme as delivered by _classification_tree.jb.
          def concept_scheme
            {
              'type' => 'object',
              'title' => 'ConceptScheme',
              'description' => t('schemas.concept_scheme'),
              'properties' => {
                '@id' => id_property,
                '@type' => { 'type' => 'string', 'const' => 'skos:ConceptScheme' },
                'dc:multilingual' => { 'type' => 'boolean' },
                'dc:translation' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
                'dc:entityUrl' => { 'type' => 'string', 'format' => 'uri' },
                'skos:prefLabel' => translatable_value,
                'dc:hasConcept' => { 'type' => 'string', 'format' => 'uri', 'description' => t('schemas.concept_scheme_has_concept') },
                'dct:created' => { 'type' => 'string', 'format' => 'date-time' },
                'dct:modified' => { 'type' => 'string', 'format' => 'date-time' },
                'dct:deleted' => { 'type' => ['string', 'null'], 'format' => 'date-time' },
                'dc:slugifiedName' => translatable_value
              },
              'required' => ['@id', '@type']
            }
          end
        end
      end
    end
  end
end
