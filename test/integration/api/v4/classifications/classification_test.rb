# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count
          end

          # TODO: add context test

          test 'api/v4/concept_schemes' do
            params = {
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(@trees)
            json_data = response.parsed_body

            validator = DataCycleCore::V4::Validation::Concept.concept_scheme

            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes with fields=dct:modified' do
            params = {
              fields: 'dc:entityUrl',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)

            assert_api_count_result(@trees)
            json_data = response.parsed_body

            fields = Dry::Schema.JSON do
              required(:'dc:entityUrl').value(:string)
            end

            validator = DataCycleCore::V4::Validation::Concept.concept_scheme(params: { fields: })

            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/(:id)' do
            tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            params = {
              id: tree.id,
              page: {
                size: 100
              }
            }
            post api_v4_concept_scheme_path(params)

            assert_response :success
            assert_equal('application/json; charset=utf-8', response.content_type)

            json_data = response.parsed_body

            validator = DataCycleCore::V4::Validation::Concept.concept_scheme

            assert_empty(validator.call(json_data['@graph'].first).errors.to_h)
          end

          test 'api/v4/concept_schemes/(:id) with fields=dc:entityUrl,dc:hasConcept' do
            tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            post_params = {
              id: tree.id,
              fields: 'dc:entityUrl,dc:hasConcept',
              page: {
                size: 100
              }
            }
            post api_v4_concept_scheme_path(post_params)

            json_data = response.parsed_body

            fields = Dry::Schema.JSON do
              required(:'dc:entityUrl').value(:string)
              required(:'dc:hasConcept').value(:string)
            end

            validator = DataCycleCore::V4::Validation::Concept.concept_scheme(params: { fields: })

            assert_empty(validator.call(json_data['@graph'].first).errors.to_h)
          end

          test 'api/v4/concept_schemes/(:id)/concepts' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body
            validator = DataCycleCore::V4::Validation::Concept.concept

            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/(:id)/concepts fields skos:prefLabel,dct:description,dct:modified' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              fields: 'skos:prefLabel,dct:description,dct:modified',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'dct:description').value(:string)
              required(:'dct:modified').value(:date_time)
            end

            concept_with_description = false
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })
            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
              # additional check to make sure at least one item has dct:description attribute
              concept_with_description = true if item['dct:description'].present?
            end

            assert(concept_with_description)
          end

          test 'api/v4/concept_schemes/(:id)/concepts/(:classification_id) fields identifier for external concepts' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id

            update_tag = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 3').first
            external_source_id = DataCycleCore::ExternalSystem.first.id
            update_tag.update_column(:external_source_id, external_source_id)
            update_tag.primary_classification.update_column(:external_source_id, external_source_id)
            update_tag.primary_classification.update_column(:external_key, 'test-identifier')

            params = {
              id: tree_id,
              classification_id: update_tag.id,
              fields: 'skos:prefLabel,dct:description,dct:modified,identifier',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            json_data = response.parsed_body
            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              required(:'dct:description').value(:string)
              required(:'dct:modified').value(:date_time)
              required(:identifier).value(:array, min_size?: 1).each do
                hash(DataCycleCore::V4::Validation::Concept::IDENTIFIER_ATTRIBUTES)
              end
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })

            assert_empty(validator.call(json_data['@graph'].first).errors.to_h)
            assert_equal('test-identifier', json_data['@graph'].first['identifier'].first['value'])

            update_tag.update_column(:external_source_id, nil)
            update_tag.primary_classification.update_column(:external_source_id, nil)
            update_tag.primary_classification.update_column(:external_key, nil)
          end

          test 'api/v4/concept_schemes/(:id)/concepts fields skos:inScheme' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              fields: 'skos:inScheme',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body

            fields = Dry::Schema.JSON do
              required(:'skos:inScheme').hash(DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER)
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })

            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/(:id)/concepts fields skos:inScheme,skos:inScheme.skos:prefLabel' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              fields: 'skos:inScheme,skos:inScheme.skos:prefLabel',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body

            fields = Dry::Schema.JSON do
              required(:'skos:inScheme').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  Dry::Schema.JSON do
                    required(:'skos:prefLabel').value(:string)
                  end
                )
              )
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })

            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/(:id)/concepts fields skos:inScheme.skos:prefLabel' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              fields: 'skos:inScheme.skos:prefLabel',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body

            fields = Dry::Schema.JSON do
              required(:'skos:inScheme').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  Dry::Schema.JSON do
                    required(:'skos:prefLabel').value(:string)
                  end
                )
              )
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })

            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/(:id)/concepts fields skos:broader.skos:inScheme.skos:prefLabel' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              fields: 'skos:broader.skos:inScheme.skos:prefLabel',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body

            fields = Dry::Schema.JSON do
              optional(:'skos:broader').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  Dry::Schema.JSON do
                    required(:'skos:inScheme').hash(
                      DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                        Dry::Schema.JSON do
                          required(:'skos:prefLabel').value(:string)
                        end
                      )
                    )
                  end
                )
              )
            end

            concept_with_broader = false
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })
            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
              # additional check to make sure at least one item has skos:broader attribute
              concept_with_broader = true if item.dig('skos:broader', 'skos:inScheme').present?
            end

            assert(concept_with_broader)
          end

          test 'api/v4/concept_schemes/(:id)/concepts include skos:inScheme' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              include: 'skos:inScheme',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body

            include = Dry::Schema.JSON do
              required(:'skos:inScheme').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_SCHEME_ATTRIBUTES
                )
              )
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { include: })

            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/(:id)/concepts include skos:broader.skos:inScheme' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              include: 'skos:broader.skos:inScheme'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body

            include = Dry::Schema.JSON do
              optional(:'skos:broader').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_ATTRIBUTES.merge(
                    Dry::Schema.JSON do
                      required(:'skos:inScheme').hash(
                        DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                          DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_SCHEME_ATTRIBUTES
                        )
                      )
                    end
                  )
                )
              )
            end

            concept_with_broader = false
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { include: })
            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
              # additional check to make sure at least one item has skos:broader attribute
              concept_with_broader = true if item.dig('skos:broader', 'skos:inScheme').present?
            end

            assert(concept_with_broader)
          end

          test 'api/v4/concept_schemes/(:id)/concepts include skos:ancestors' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              include: 'skos:ancestors',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body

            include = Dry::Schema.JSON do
              optional(:'skos:ancestors').value(:array, min_size?: 1).each do
                hash(
                  DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                    DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_ATTRIBUTES
                  )
                )
              end
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { include: })
            concept_with_ancestor = false
            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
              # additional check to make sure at least one item has skos:ancestors attribute
              concept_with_ancestor = true if item['skos:ancestors'].present?
            end

            assert(concept_with_ancestor)
          end

          test 'api/v4/concept_schemes/(:id)/concepts include skos:ancestors fields skos:prefLabel' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              include: 'skos:ancestors',
              fields: 'skos:prefLabel',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'skos:ancestors').value(:array, min_size?: 1).each do
                hash(
                  DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                    DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_ATTRIBUTES
                  )
                )
              end
            end

            concept_with_ancestor = false
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })
            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
              concept_with_ancestor = true if item['skos:ancestors'].present?
            end

            assert(concept_with_ancestor)
          end

          test 'api/v4/concept_schemes/(:id)/concepts include skos:inScheme fields skos:inScheme.skos:prefLabel' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              include: 'skos:inScheme',
              fields: 'skos:inScheme.skos:prefLabel',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = response.parsed_body

            fields = Dry::Schema.JSON do
              required(:'skos:inScheme').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  Dry::Schema.JSON do
                    required(:'skos:prefLabel').value(:string)
                  end
                )
              )
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })

            json_data['@graph'].each do |item|
              assert_empty(validator.call(item).errors.to_h)
            end
          end
        end
      end
    end
  end
end
