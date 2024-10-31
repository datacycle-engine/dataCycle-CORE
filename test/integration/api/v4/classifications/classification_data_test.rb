# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationDataTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count

            @classification_tag = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Nested Tag 2').first
            I18n.with_locale(:en) do
              @classification_tag.attributes = {
                name: 'Nested Tag 2 - EN',
                description: 'Nested Tag 2 - Description'
              }
            end
            @classification_tag.save
          end

          # TODO: test full concept data is returned with correct values
          test 'api/v4/concept_schemes/(:id) test full concept scheme with correct values' do
            tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            tree_id = tree.id

            params = {
              id: tree_id
            }
            post api_v4_concept_scheme_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup['@graph'].first

            assert_context(json_data['@context'], 'de')

            assert_json_attributes(json_validate) do
              {
                '@id' => tree.id,
                '@type' => 'skos:ConceptScheme',
                'dc:translation' => ['de'],
                'dc:multilingual' => false,
                'skos:prefLabel' => tree.name
              }
            end

            assert_json_attributes(json_validate) do
              {
                'dct:created' => tree.created_at.as_json,
                'dct:modified' => tree.updated_at.as_json
              }
            end

            assert_json_attributes(json_validate) do
              {
                'dc:entityUrl' => api_v4_concept_scheme_url(id: tree.id, language: 'de'),
                'dc:hasConcept' => classifications_api_v4_concept_scheme_url(id: tree.id, language: 'de')
              }
            end

            assert_equal({}, json_validate)
          end

          # TODO: test full concept data is returned with correct values
          test 'api/v4/concept_schemes/(:id) test full concept scheme with language en' do
            tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            tree_id = tree.id

            params = {
              id: tree_id,
              language: 'en'
            }
            post api_v4_concept_scheme_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup['@graph'].first

            assert_context(json_data['@context'], params[:language])

            assert_json_attributes(json_validate) do
              {
                '@id' => tree.id,
                '@type' => 'skos:ConceptScheme',
                'dc:translation' => ['de'],
                'dc:multilingual' => false
              }
            end

            assert_json_attributes(json_validate) do
              {
                'dct:created' => tree.created_at.as_json,
                'dct:modified' => tree.updated_at.as_json
              }
            end

            assert_json_attributes(json_validate) do
              {
                'dc:entityUrl' => api_v4_concept_scheme_url(id: tree.id, language: 'en'),
                'dc:hasConcept' => classifications_api_v4_concept_scheme_url(id: tree.id, language: 'en')
              }
            end

            assert_json_attributes(json_validate) do
              {
                'skos:prefLabel' => [
                  {
                    '@language' => 'de',
                    '@value' => tree.name
                  }
                ]
              }
            end

            assert_equal({}, json_validate)
          end

          # TODO: test full concept data is returned with correct values
          test 'api/v4/concept_schemes/(:id) test full concept scheme with language en,de' do
            tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            tree_id = tree.id

            params = {
              id: tree_id,
              language: 'en,de'
            }
            post api_v4_concept_scheme_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup['@graph'].first

            assert_context(json_data['@context'], params[:language])

            assert_json_attributes(json_validate) do
              {
                '@id' => tree.id,
                '@type' => 'skos:ConceptScheme',
                'dc:translation' => ['de'],
                'dc:multilingual' => false
              }
            end

            assert_json_attributes(json_validate) do
              {
                'dct:created' => tree.created_at.as_json,
                'dct:modified' => tree.updated_at.as_json
              }
            end

            assert_json_attributes(json_validate) do
              {
                'dc:entityUrl' => api_v4_concept_scheme_url(id: tree.id, language: 'en,de'),
                'dc:hasConcept' => classifications_api_v4_concept_scheme_url(id: tree.id, language: 'en,de')
              }
            end

            assert_json_attributes(json_validate) do
              {
                'skos:prefLabel' => [
                  {
                    '@language' => 'de',
                    '@value' => tree.name
                  }
                ]
              }
            end

            assert_equal({}, json_validate)
          end

          test 'api/v4/concept_schemes/(:id)/concepts/(:classification_id) with full data' do
            tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            tree_id = tree.id

            update_tag = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Nested Tag 2').first
            external_source = DataCycleCore::ExternalSystem.first
            external_source_id = external_source.id
            update_tag.update_column(:external_source_id, external_source_id)
            update_tag.primary_classification.update_column(:external_source_id, external_source_id)
            update_tag.primary_classification.update_column(:external_key, 'test-identifier')

            params = {
              id: tree_id,
              classification_id: update_tag.id,
              include: 'skos:inScheme,skos:broader,skos:ancestors,skos:topConceptOf'
            }
            post classifications_api_v4_concept_scheme_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup['@graph'].first

            assert_context(json_data['@context'], params[:language])

            assert_json_attributes(json_validate) do
              {
                '@id' => update_tag.id,
                '@type' => 'skos:Concept',
                'dc:translation' => update_tag.available_locales.map(&:to_s),
                'dc:multilingual' => true,
                'skos:prefLabel' => update_tag.name,
                'dct:created' => update_tag.created_at.as_json,
                'dct:modified' => update_tag.updated_at.as_json,
                'dc:entityUrl' => classifications_api_v4_concept_scheme_url(id: tree_id, classification_id: update_tag.id, language: 'de'),
                'dct:description' => update_tag.description,
                'url' => update_tag.uri
              }
            end

            assert_json_attributes(json_validate) do
              {
                'skos:inScheme' => {
                  '@id' => tree_id,
                  '@type' => 'skos:ConceptScheme',
                  'dc:translation' => ['de'],
                  'dc:multilingual' => false,
                  'skos:prefLabel' => tree.name,
                  'dc:entityUrl' => api_v4_concept_scheme_url(id: tree.id, language: 'de'),
                  'dc:hasConcept' => classifications_api_v4_concept_scheme_url(id: tree.id, language: 'de'),
                  'dct:created' => tree.created_at.as_json,
                  'dct:modified' => tree.updated_at.as_json
                }
              }
            end

            ancestors = update_tag.ancestors.to_a[0..2]
            broader = ancestors.first
            assert_json_attributes(json_validate) do
              {
                'skos:broader' => {
                  '@id' => broader.id,
                  '@type' => 'skos:Concept',
                  'dc:translation' => broader.available_locales.map(&:to_s),
                  'dc:multilingual' => true,
                  'skos:prefLabel' => broader.name,
                  'dct:created' => broader.created_at.as_json,
                  'dct:modified' => broader.updated_at.as_json,
                  'dc:entityUrl' => classifications_api_v4_concept_scheme_url(id: tree_id, classification_id: broader.id, language: 'de'),
                  'dct:description' => broader.description,
                  'url' => broader.uri,
                  'skos:inScheme' => {
                    '@id' => tree_id,
                    '@type' => 'skos:ConceptScheme'
                  },
                  'skos:topConceptOf' => {
                    '@id' => tree_id,
                    '@type' => 'skos:ConceptScheme'
                  }
                }
              }
            end

            assert_json_attributes(json_validate) do
              {
                'skos:ancestors' => [
                  {
                    '@id' => broader.id,
                    '@type' => 'skos:Concept',
                    'dc:translation' => broader.available_locales.map(&:to_s),
                    'dc:multilingual' => true,
                    'skos:prefLabel' => broader.name,
                    'dct:created' => broader.created_at.as_json,
                    'dct:modified' => broader.updated_at.as_json,
                    'dc:entityUrl' => classifications_api_v4_concept_scheme_url(id: tree_id, classification_id: broader.id, language: 'de'),
                    'dct:description' => broader.description,
                    'url' => broader.uri,
                    'skos:inScheme' => {
                      '@id' => tree_id,
                      '@type' => 'skos:ConceptScheme'
                    },
                    'skos:topConceptOf' => {
                      '@id' => tree_id,
                      '@type' => 'skos:ConceptScheme'
                    }
                  }
                ]
              }
            end

            assert_equal({}, json_validate)

            update_tag.update_column(:external_source_id, nil)
            update_tag.primary_classification.update_column(:external_source_id, nil)
            update_tag.primary_classification.update_column(:external_key, nil)
          end

          test 'api/v4/concept_schemes/(:id)/concepts/(:classification_id) with full data and language=en' do
            tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            tree_id = tree.id

            update_tag = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Nested Tag 2').first
            external_source = DataCycleCore::ExternalSystem.first
            external_source_id = external_source.id
            update_tag.update_column(:external_source_id, external_source_id)
            update_tag.primary_classification.update_column(:external_source_id, external_source_id)
            update_tag.primary_classification.update_column(:external_key, 'test-identifier')

            params = {
              id: tree_id,
              language: 'en',
              classification_id: update_tag.id,
              include: 'skos:inScheme,skos:broader,skos:ancestors,skos:topConceptOf'
            }
            post classifications_api_v4_concept_scheme_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup['@graph'].first

            assert_context(json_data['@context'], params[:language])

            I18n.with_locale('en') do
              assert_json_attributes(json_validate) do
                {
                  '@id' => update_tag.id,
                  '@type' => 'skos:Concept',
                  'dc:translation' => update_tag.available_locales.map(&:to_s),
                  'dc:multilingual' => true,
                  'skos:prefLabel' => update_tag.name,
                  'dct:created' => update_tag.created_at.as_json,
                  'dct:modified' => update_tag.updated_at.as_json,
                  'dc:entityUrl' => classifications_api_v4_concept_scheme_url(id: tree_id, classification_id: update_tag.id, language: 'en'),
                  'dct:description' => update_tag.description,
                  'url' => update_tag.uri
                }
              end
            end

            assert_json_attributes(json_validate) do
              {
                'skos:inScheme' => {
                  '@id' => tree_id,
                  '@type' => 'skos:ConceptScheme',
                  'dc:translation' => ['de'],
                  'dc:multilingual' => false,
                  'skos:prefLabel' => [
                    {
                      '@language' => 'de',
                      '@value' => tree.name
                    }
                  ],
                  'dc:entityUrl' => api_v4_concept_scheme_url(id: tree.id, language: 'en'),
                  'dc:hasConcept' => classifications_api_v4_concept_scheme_url(id: tree.id, language: 'en'),
                  'dct:created' => tree.created_at.as_json,
                  'dct:modified' => tree.updated_at.as_json
                }
              }
            end

            ancestors = update_tag.ancestors.to_a[0..2]
            broader = ancestors.first

            assert_json_attributes(json_validate) do
              {
                'skos:broader' => {
                  '@id' => broader.id,
                  '@type' => 'skos:Concept',
                  'dc:translation' => broader.available_locales.map(&:to_s),
                  'dc:multilingual' => true,
                  'skos:prefLabel' => [
                    {
                      '@language' => 'de',
                      '@value' => broader.name
                    }
                  ],
                  'dct:created' => broader.created_at.as_json,
                  'dct:modified' => broader.updated_at.as_json,
                  'dc:entityUrl' => classifications_api_v4_concept_scheme_url(id: tree_id, classification_id: broader.id, language: 'en'),
                  'dct:description' => [
                    {
                      '@language' => 'de',
                      '@value' => broader.description
                    }
                  ],
                  'url' => broader.uri,
                  'skos:inScheme' => {
                    '@id' => tree_id,
                    '@type' => 'skos:ConceptScheme'
                  },
                  'skos:topConceptOf' => {
                    '@id' => tree_id,
                    '@type' => 'skos:ConceptScheme'
                  }
                }
              }
            end

            assert_json_attributes(json_validate) do
              {
                'skos:ancestors' => [
                  {
                    '@id' => broader.id,
                    '@type' => 'skos:Concept',
                    'dc:translation' => broader.available_locales.map(&:to_s),
                    'dc:multilingual' => true,
                    'skos:prefLabel' => [
                      {
                        '@language' => 'de',
                        '@value' => broader.name
                      }
                    ],
                    'dct:created' => broader.created_at.as_json,
                    'dct:modified' => broader.updated_at.as_json,
                    'dc:entityUrl' => classifications_api_v4_concept_scheme_url(id: tree_id, classification_id: broader.id, language: 'en'),
                    'dct:description' => [
                      {
                        '@language' => 'de',
                        '@value' => broader.description
                      }
                    ],
                    'url' => broader.uri,
                    'skos:inScheme' => {
                      '@id' => tree_id,
                      '@type' => 'skos:ConceptScheme'
                    },
                    'skos:topConceptOf' => {
                      '@id' => tree_id,
                      '@type' => 'skos:ConceptScheme'
                    }
                  }
                ]
              }
            end

            assert_equal({}, json_validate)

            update_tag.update_column(:external_source_id, nil)
            update_tag.primary_classification.update_column(:external_source_id, nil)
            update_tag.primary_classification.update_column(:external_key, nil)
          end

          test 'api/v4/concept_schemes/(:id)/concepts/(:classification_id) with full data and language=en,de,it' do
            tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            tree_id = tree.id

            update_tag = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Nested Tag 2').first
            external_source = DataCycleCore::ExternalSystem.first
            external_source_id = external_source.id
            update_tag.update_column(:external_source_id, external_source_id)
            update_tag.primary_classification.update_column(:external_source_id, external_source_id)
            update_tag.primary_classification.update_column(:external_key, 'test-identifier')

            params = {
              id: tree_id,
              language: 'en,de,it',
              classification_id: update_tag.id,
              include: 'skos:inScheme,skos:broader,skos:ancestors,skos:topConceptOf'
            }
            post classifications_api_v4_concept_scheme_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup['@graph'].first

            assert_context(json_data['@context'], params[:language])

            pref_label = []
            I18n.with_locale('en') do
              pref_label <<
                {
                  '@language' => 'en',
                  '@value' => update_tag.name
                }
            end
            pref_label <<
              {
                '@language' => 'de',
                '@value' => update_tag.name
              }

            description = []
            I18n.with_locale('en') do
              description <<
                {
                  '@language' => 'en',
                  '@value' => update_tag.description
                }
            end

            description <<
              {
                '@language' => 'de',
                '@value' => update_tag.description
              }

            assert_json_attributes(json_validate) do
              {
                '@id' => update_tag.id,
                '@type' => 'skos:Concept',
                'dc:translation' => update_tag.available_locales.map(&:to_s),
                'dc:multilingual' => true,
                'skos:prefLabel' => pref_label,
                'dct:created' => update_tag.created_at.as_json,
                'dct:modified' => update_tag.updated_at.as_json,
                'dc:entityUrl' => classifications_api_v4_concept_scheme_url(id: tree_id, classification_id: update_tag.id, language: 'en,de'),
                'dct:description' => description,
                'url' => update_tag.uri
              }
            end

            assert_json_attributes(json_validate) do
              {
                'skos:inScheme' => {
                  '@id' => tree_id,
                  '@type' => 'skos:ConceptScheme',
                  'skos:prefLabel' => [
                    {
                      '@language' => 'de',
                      '@value' => tree.name
                    }
                  ],
                  'dc:translation' => ['de'],
                  'dc:multilingual' => false,
                  'dc:entityUrl' => api_v4_concept_scheme_url(id: tree.id, language: 'en,de'),
                  'dc:hasConcept' => classifications_api_v4_concept_scheme_url(id: tree.id, language: 'en,de'),
                  'dct:created' => tree.created_at.as_json,
                  'dct:modified' => tree.updated_at.as_json
                }
              }
            end

            ancestors = update_tag.ancestors.to_a[0..2]
            broader = ancestors.first

            assert_json_attributes(json_validate) do
              {
                'skos:broader' => {
                  '@id' => broader.id,
                  '@type' => 'skos:Concept',
                  'dc:translation' => broader.available_locales.map(&:to_s),
                  'dc:multilingual' => true,
                  'skos:prefLabel' => [
                    {
                      '@language' => 'de',
                      '@value' => broader.name
                    }
                  ],
                  'dct:created' => broader.created_at.as_json,
                  'dct:modified' => broader.updated_at.as_json,
                  'dc:entityUrl' => classifications_api_v4_concept_scheme_url(id: tree_id, classification_id: broader.id, language: 'en,de'),
                  'dct:description' => [
                    {
                      '@language' => 'de',
                      '@value' => broader.description
                    }
                  ],
                  'url' => broader.uri,
                  'skos:inScheme' => {
                    '@id' => tree_id,
                    '@type' => 'skos:ConceptScheme'
                  },
                  'skos:topConceptOf' => {
                    '@id' => tree_id,
                    '@type' => 'skos:ConceptScheme'
                  }
                }
              }
            end

            assert_json_attributes(json_validate) do
              {
                'skos:ancestors' => [
                  {
                    '@id' => broader.id,
                    '@type' => 'skos:Concept',
                    'dc:translation' => broader.available_locales.map(&:to_s),
                    'dc:multilingual' => true,
                    'skos:prefLabel' => [
                      {
                        '@language' => 'de',
                        '@value' => broader.name
                      }
                    ],
                    'dct:created' => broader.created_at.as_json,
                    'dct:modified' => broader.updated_at.as_json,
                    'dc:entityUrl' => classifications_api_v4_concept_scheme_url(id: tree_id, classification_id: broader.id, language: 'en,de'),
                    'dct:description' => [
                      {
                        '@language' => 'de',
                        '@value' => broader.description
                      }
                    ],
                    'url' => broader.uri,
                    'skos:inScheme' => {
                      '@id' => tree_id,
                      '@type' => 'skos:ConceptScheme'
                    },
                    'skos:topConceptOf' => {
                      '@id' => tree_id,
                      '@type' => 'skos:ConceptScheme'
                    }
                  }
                ]
              }
            end

            assert_equal({}, json_validate)

            update_tag.update_column(:external_source_id, nil)
            update_tag.primary_classification.update_column(:external_source_id, nil)
            update_tag.primary_classification.update_column(:external_key, nil)
          end

          test 'api/v4/concept_schemes/(:id)/concepts/(:classification_id) with identifier' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id

            update_tag = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 3').first
            external_source = DataCycleCore::ExternalSystem.first
            external_source_id = external_source.id
            update_tag.update_column(:external_source_id, external_source_id)
            update_tag.primary_classification.update_column(:external_source_id, external_source_id)
            update_tag.primary_classification.update_column(:external_key, 'test-identifier')

            params = {
              id: tree_id,
              classification_id: update_tag.id,
              fields: 'identifier'
            }
            post classifications_api_v4_concept_scheme_path(params)

            json_data = response.parsed_body
            json_validate = json_data.dup['@graph'].first

            assert_context(json_data['@context'], params['de'])

            assert_json_attributes(json_validate) do
              {
                '@id' => update_tag.id,
                '@type' => 'skos:Concept',
                'identifier' => [
                  {
                    '@type' => 'PropertyValue',
                    'propertyID' => external_source.identifier,
                    'value' => 'test-identifier'
                  }
                ]
              }
            end

            assert_equal({}, json_validate)

            update_tag.update_column(:external_source_id, nil)
            update_tag.primary_classification.update_column(:external_source_id, nil)
            update_tag.primary_classification.update_column(:external_key, nil)
          end
        end
      end
    end
  end
end
