# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationDataTest < DataCycleCore::V4::Base
          setup do
            DataCycleCore::Thing.where(template: false).delete_all
            @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count
          end

          # TODO: test full concept data is returned with correct values
          test 'api/v4/concept_schemes/(:id) test full concept scheme with correct values' do
            tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            tree_id = tree.id

            params = {
              id: tree_id
            }
            post api_v4_concept_scheme_path(params)

            json_data = JSON.parse(response.body)
            json_validate = json_data.dup

            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            assert_json_attributes(json_validate) do
              {
                '@id' => tree.id,
                '@type' => 'skos:ConceptScheme',
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

            json_data = JSON.parse(response.body)
            json_validate = json_data.dup

            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            assert_json_attributes(json_validate) do
              {
                '@id' => tree.id,
                '@type' => 'skos:ConceptScheme'
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

            json_data = JSON.parse(response.body)
            json_validate = json_data.dup

            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            assert_json_attributes(json_validate) do
              {
                '@id' => tree.id,
                '@type' => 'skos:ConceptScheme'
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
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id

            update_tag = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 3').first
            external_source = DataCycleCore::ExternalSource.first
            external_source_id = external_source.id
            update_tag.update_column(:external_source_id, external_source_id) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_source_id, external_source_id) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_key, 'test-identifier') # rubocop:disable Rails/SkipsModelValidations

            params = {
              id: tree_id,
              classification_id: update_tag.id,
              include: 'skos:inScheme,skos:broader,skos:ancestors,skos:topConceptOf'
            }
            post classifications_api_v4_concept_scheme_path(params)

            json_data = JSON.parse(response.body)
            json_validate = json_data.dup

            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            assert_json_attributes(json_validate) do
              {
                '@id' => update_tag.id,
                '@type' => 'skos:Concept',
                'skos:prefLabel' => update_tag.name,
                'dct:created' => update_tag.created_at.as_json,
                'dct:modified' => update_tag.updated_at.as_json,
                'dc:entityUrl' => classifications_api_v4_concept_scheme_url(id: tree_id, classification_id: update_tag.id, language: 'de'),
                'dct:description' => update_tag.description,
                'url' => update_tag.uri
              }
            end

            assert_equal({}, json_validate)

            update_tag.update_column(:external_source_id, nil) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_source_id, nil) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_key, nil) # rubocop:disable Rails/SkipsModelValidations
          end

          test 'api/v4/concept_schemes/(:id)/concepts/(:classification_id) with identifier' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id

            update_tag = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 3').first
            external_source = DataCycleCore::ExternalSource.first
            external_source_id = external_source.id
            update_tag.update_column(:external_source_id, external_source_id) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_source_id, external_source_id) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_key, 'test-identifier') # rubocop:disable Rails/SkipsModelValidations

            params = {
              id: tree_id,
              classification_id: update_tag.id,
              fields: 'identifier'
            }
            post classifications_api_v4_concept_scheme_path(params)

            json_data = JSON.parse(response.body)
            json_validate = json_data.dup

            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            assert_json_attributes(json_validate) do
              {
                '@id' => update_tag.id,
                '@type' => 'skos:Concept',
                'identifier' => [
                  {
                    '@type' => 'PropertyValue',
                    'propertyID' => external_source.name,
                    'value' => 'test-identifier'
                  }
                ]
              }
            end

            assert_equal({}, json_validate)

            update_tag.update_column(:external_source_id, nil) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_source_id, nil) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_key, nil) # rubocop:disable Rails/SkipsModelValidations
          end
        end
      end
    end
  end
end
